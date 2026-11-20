// How a pasted file link becomes something the app can play itself.
//
// A Dropbox share link (https://www.dropbox.com/scl/fi/<id>/clip.mp4?rlkey=…&dl=0) opens Dropbox's own preview page, which the app cannot
// control — so autoplay cannot be controlled either. The same link with `raw=1` (and no `dl=`) makes Dropbox hand back the file itself,
// which the app's own player can play, and then autoplay is the viewer's choice. Folder links and files a browser cannot play (no
// recognisable video extension) stay ordinary links that open in Dropbox.

/// File types a browser's video player can play.
const kPlayableVideoExtensions = {'mp4', 'm4v', 'mov', 'webm', 'ogv'};

class MediaLink {
  const MediaLink._({required this.original, required this.isDropbox, required this.isFolder, this.fileName = '', this.playUrl, this.altPlayUrl});

  /// What was pasted, untouched — "Open in Dropbox" always opens this.
  final String original;
  final bool isDropbox;

  /// A Dropbox folder (it holds many files; it cannot be played).
  final bool isFolder;
  final String fileName;

  /// A direct address the player can stream, or null when the app cannot play this link inline.
  final String? playUrl;

  /// A second route to the same file, tried when [playUrl] does not play: Dropbox's direct content host. It has no redirect to another host,
  /// which is where some browsers, extensions and networks stumble. Null for a link that has no such form.
  final String? altPlayUrl;

  bool get canPlayInline => playUrl != null;

  /// Every address worth trying, best first.
  List<String> get playUrls => [?playUrl, ?altPlayUrl];

  /// Reads [url]. Never throws: anything that is not a link becomes a link that cannot be played inline.
  factory MediaLink.parse(String? url) {
    final raw = (url ?? '').trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return MediaLink._(original: raw, isDropbox: false, isFolder: false);
    }
    final host = uri.host.toLowerCase();
    final fileName = uri.pathSegments.isEmpty ? '' : Uri.decodeComponent(uri.pathSegments.last);
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final video = kPlayableVideoExtensions.contains(ext);

    final isDropboxHost = host == 'dropbox.com' || host.endsWith('.dropbox.com');
    final isDropboxContent = host == 'dl.dropboxusercontent.com' || host.endsWith('.dropboxusercontent.com');
    if (!isDropboxHost && !isDropboxContent) {
      // any other direct video file link can be played as it is
      return MediaLink._(original: raw, isDropbox: false, isFolder: false, fileName: fileName, playUrl: video ? raw : null);
    }

    final segs = uri.pathSegments;
    // /sh/<id>/… (old) and /scl/fo/<id>/… (new) are folders
    final isFolder = isDropboxHost && segs.isNotEmpty && (segs.first == 'sh' || (segs.length > 1 && segs[0] == 'scl' && segs[1] == 'fo'));
    if (isFolder || !video) {
      return MediaLink._(original: raw, isDropbox: true, isFolder: isFolder, fileName: fileName);
    }
    if (isDropboxContent) return MediaLink._(original: raw, isDropbox: true, isFolder: false, fileName: fileName, playUrl: raw);
    // keep every parameter Dropbox needs (rlkey, st…), drop the "dl" ones, ask for the file itself
    final q = Map<String, String>.from(uri.queryParameters)..remove('dl')..['raw'] = '1';
    final direct = Map<String, String>.from(uri.queryParameters)..remove('dl')..remove('raw');
    return MediaLink._(
      original: raw,
      isDropbox: true,
      isFolder: false,
      fileName: fileName,
      playUrl: uri.replace(queryParameters: q).toString(),
      altPlayUrl: Uri(scheme: 'https', host: 'dl.dropboxusercontent.com', pathSegments: uri.pathSegments, queryParameters: direct.isEmpty ? null : direct).toString(),
    );
  }
}
