/// One file the user chose to upload, independent of where it came from
/// (file picker, photo library, camera). Pickers disagree on file types
/// (`PlatformFile` vs `XFile`) and on whether a real path exists (Android
/// content URIs often have none) — so everything downstream sees only a
/// name, a mime type, a byte count, and a way to stream the bytes.
class PickedUpload {
  const PickedUpload({
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.openRead,
  });

  final String name;

  /// Null when the extension isn't a type the backend accepts.
  final String? mime;
  final int sizeBytes;

  /// Streams the file's bytes. Never loads the whole file into memory —
  /// uploads go up to 50 MiB.
  final Stream<List<int>> Function() openRead;
}
