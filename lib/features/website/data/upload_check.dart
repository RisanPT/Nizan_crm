import 'package:nizan_crm/features/website/data/website_models.dart';

/// MIME type for a file name, by extension ('' when not an allowed image type).
String imageMimeFor(String filename) {
  final dot = filename.lastIndexOf('.');
  final ext = dot == -1 ? '' : filename.substring(dot).toLowerCase();
  switch (ext) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    default:
      return '';
  }
}

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '${mb == mb.roundToDouble() ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).round()} KB';
}

/// Quick check in the CRM before uploading, so staff get instant feedback.
/// The server repeats every check on the real file bytes — this is only a convenience.
/// Returns null when the file looks fine, else a message to show.
String? checkPickedImage(
  UploadRule rule, {
  required String filename,
  required int bytes,
  int? width,
  int? height,
}) {
  final dot = filename.lastIndexOf('.');
  final ext = dot == -1 ? '' : filename.substring(dot).toLowerCase();
  if (!rule.extensions.contains(ext)) {
    final allowed = rule.pickerExtensions
        .map((e) => e.toUpperCase())
        .toSet()
        .join(', ');
    return '"$filename" is not allowed here. Use $allowed.';
  }
  if (bytes > rule.maxBytes) {
    return '"$filename" is ${formatBytes(bytes)}. The limit here is ${formatBytes(rule.maxBytes)}.';
  }
  if (width == null || height == null || width == 0 || height == 0) {
    return null; // server will decide
  }
  if (width < rule.minWidth || height < rule.minHeight) {
    return 'This image is $width × $height px. It must be at least '
        '${rule.minWidth} × ${rule.minHeight} px.';
  }
  final ratio = rule.ratio;
  if (ratio != null && ratio.length == 2) {
    final r = width / height;
    if (r < ratio[0] - 0.005 || r > ratio[1] + 0.005) {
      return 'This image is $width × $height px — the wrong shape. Needed: ${rule.shape}.';
    }
  }
  return null;
}
