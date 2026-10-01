import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'picked_upload.dart';
import 'upload_constraints.dart';

enum UploadSource { file, photoLibrary, camera }

/// The user's choice couldn't be turned into a file (permission denied,
/// unreadable file). [message] is plain language, safe to show.
final class UploadPickException implements Exception {
  const UploadPickException(this.message);
  final String message;
}

/// Turns an [UploadSource] into a [PickedUpload], or null when the user
/// backed out. Behind an interface so nothing above this layer touches
/// `file_picker`/`image_picker` — both have changed their APIs repeatedly
/// (file_picker 12 and 13 each broke `pickFiles`/`PlatformFile`).
abstract interface class UploadPicker {
  Future<PickedUpload?> pick(UploadSource source);
}

class DeviceUploadPicker implements UploadPicker {
  DeviceUploadPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<PickedUpload?> pick(UploadSource source) {
    switch (source) {
      case UploadSource.file:
        return _pickFile();
      case UploadSource.photoLibrary:
        return _pickImage(ImageSource.gallery);
      case UploadSource.camera:
        return _pickImage(ImageSource.camera);
    }
  }

  Future<PickedUpload?> _pickFile() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: kUploadFileExtensions,
      );
    } on PlatformException {
      throw const UploadPickException("Couldn't open the file picker.");
    }
    if (file == null) return null;

    // `length()` is nullable since file_picker 13: null means the size
    // couldn't be determined, which is not the same as an empty file.
    final size = await file.length();
    if (size == null) {
      throw const UploadPickException("Couldn't read that file's size.");
    }
    return PickedUpload(
      name: file.name,
      mime: uploadMimeForFileName(file.name),
      sizeBytes: size,
      openRead: file.readAsByteStream,
    );
  }

  Future<PickedUpload?> _pickImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await _imagePicker.pickImage(source: source);
    } on PlatformException catch (e) {
      throw UploadPickException(_messageForImagePickerError(e, source));
    }
    if (picked == null) return null;

    final name = source == ImageSource.camera
        ? _cameraFileName(picked.name)
        : picked.name;
    return PickedUpload(
      name: name,
      mime: uploadMimeForFileName(name),
      sizeBytes: await picked.length(),
      openRead: picked.openRead,
    );
  }

  /// The camera plugin hands back an opaque temp name; a timestamped one
  /// is what ends up in the user's document list.
  String _cameraFileName(String original) {
    final dot = original.lastIndexOf('.');
    final extension = dot >= 0 && dot < original.length - 1
        ? original.substring(dot)
        : '.jpg';
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'photo-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}$extension';
  }

  String _messageForImagePickerError(PlatformException e, ImageSource source) {
    switch (e.code) {
      case 'camera_access_denied':
        return 'Camera access is turned off. Enable it in Settings to take a photo.';
      case 'photo_access_denied':
        return 'Photo access is turned off. Enable it in Settings to choose a photo.';
    }
    return source == ImageSource.camera
        ? "Couldn't open the camera."
        : "Couldn't open your photo library.";
  }
}
