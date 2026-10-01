/// 50 MiB — binary, not decimal MB. Re-confirmed from the backend's own
/// source (`MAX_UPLOAD_BYTES = 50 * 1024 * 1024` in
/// `services/api/app/core/documents_storage.py`, whose comment records it
/// was pinned empirically to the exact byte: 52428800 succeeds,
/// 52428801 fails with `EntityTooLarge`) rather than assumed from the
/// web project. Client-side enforcement is UX only — Supabase Storage's
/// bucket limit is the real boundary, per `architecture-and-spec.md` §3.
const int kMaxUploadBytes = 52428800;

/// Mirrors the backend's `ALLOWED_MIME_TYPES` exactly (same set the web
/// upload page mirrors). Extension → mime, because the pickers report
/// names far more reliably than mime types across platforms.
const Map<String, String> kUploadMimeByExtension = {
  'txt': 'text/plain',
  'md': 'text/markdown',
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

final List<String> kUploadFileExtensions = List.unmodifiable(
  kUploadMimeByExtension.keys,
);

final Set<String> kAllowedUploadMimeTypes = Set.unmodifiable(
  kUploadMimeByExtension.values,
);

/// The mime type for a filename, from its extension, or null when it isn't
/// a type the backend accepts.
String? uploadMimeForFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return null;
  return kUploadMimeByExtension[fileName.substring(dot + 1).toLowerCase()];
}

/// Plain-language reason this file can't be uploaded, or null when it
/// can. Fast feedback only — the backend re-checks both rules, and
/// Storage enforces the size for real.
String? validateUpload({required String? mime, required int sizeBytes}) {
  if (mime == null || !kAllowedUploadMimeTypes.contains(mime)) {
    return 'Unsupported file type: ${mime ?? 'unknown'}';
  }
  if (sizeBytes > kMaxUploadBytes) {
    return 'File exceeds the 50MB upload limit';
  }
  return null;
}
