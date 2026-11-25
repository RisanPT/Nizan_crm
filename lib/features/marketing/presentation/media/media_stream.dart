import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';

// A gallery video PLAYED THROUGH OUR OWN SERVER (backend /api/marketing/media). Straight from Dropbox a video often fails in ways the app
// cannot fix: Dropbox sends the wrong file type (Firefox and Safari then refuse it), pauses a link that is opened a lot, and some networks
// block its hosts. The server fetches the file from Dropbox — only from Dropbox — sends it on with the right type and byte ranges, keeps
// a copy so the same video is not fetched from Dropbox again and again, and, when Dropbox refuses, says why in plain words.
//
// The address the player gets carries a short-lived signed token (the <video> tag cannot send the login) — never the login token.

/// What the server answered for a Dropbox video link.
class MediaStreamLink {
  const MediaStreamLink({this.url = '', this.ok = true, this.code = '', this.message = '', this.retryDirect = false, this.directUrl = '', this.directUntil});

  /// The address to stream from ('' when the server gave none).
  final String url;

  /// False when Dropbox refused the file (then [code] and [message] say why).
  final bool ok;
  final String code, message;

  /// Worth trying Dropbox's own routes anyway (the server could not reach Dropbox; the viewer's own network may).
  final bool retryDirect;

  /// A link straight from Dropbox (the file is in the company's own Dropbox) and when it stops working (Dropbox's last 4 hours). Played
  /// first, so the video never passes through our server.
  final String directUrl;
  final DateTime? directUntil;

  /// Where to play from, best first: straight from Dropbox while its link has at least 5 minutes left, then through the server.
  List<String> sourcesAt(DateTime now) => [
        if (directUrl.isNotEmpty && (directUntil == null || directUntil!.isAfter(now.add(const Duration(minutes: 5))))) directUrl,
        if (url.isNotEmpty) url,
      ];
  List<String> get sources => sourcesAt(DateTime.now());

  factory MediaStreamLink.fromJson(Map<String, dynamic> j, String apiBase) {
    final path = (j['path'] ?? '').toString();
    final direct = j['direct'];
    return MediaStreamLink(
      url: path.isEmpty ? '' : mediaStreamAddress(apiBase, path),
      ok: j['ok'] != false,
      code: (j['code'] ?? '').toString(),
      message: (j['message'] ?? '').toString(),
      retryDirect: j['retryDirect'] == true,
      directUrl: direct is Map ? (direct['url'] ?? '').toString() : '',
      directUntil: direct is Map ? DateTime.tryParse((direct['until'] ?? '').toString())?.toLocal() : null,
    );
  }
}

/// The API's base (`https://api…/api`) and the server's path (`/marketing/media/stream/TOKEN`) → the full address.
String mediaStreamAddress(String apiBase, String path) {
  final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
  return '$base${path.startsWith('/') ? path : '/$path'}';
}

/// One file inside a Dropbox folder (as the server listed it).
class FolderFile {
  const FolderFile({required this.name, required this.path, this.size = 0, this.modifiedAt, this.media = 'other', this.showable = false});
  final String name, path;
  final int size;
  final DateTime? modifiedAt;

  /// 'video' | 'picture' | 'other'.
  final String media;

  /// The app can play / show it itself (an mp4, mov, m4v, webm video; a jpg, png, webp picture). The rest opens in Dropbox.
  final bool showable;

  factory FolderFile.fromJson(Map<String, dynamic> j) => FolderFile(
        name: (j['name'] ?? '').toString(),
        path: (j['path'] ?? '').toString(),
        size: (j['size'] as num?)?.toInt() ?? 0,
        modifiedAt: DateTime.tryParse((j['modifiedAt'] ?? '').toString())?.toLocal(),
        media: (j['media'] ?? 'other').toString(),
        showable: j['showable'] == true,
      );
}

/// What is inside a Dropbox FOLDER link (an artist's footage folder) — listed by the server through its Dropbox app. Without the app
/// ([connected] false) the server still says how to open the folder: in Dropbox, or all of it as one .zip ([zipUrl]).
class DropboxFolderListing {
  const DropboxFolderListing({this.url = '', this.path = '', this.zipUrl = '', this.connected = false, this.ok = false, this.code = '', this.message = '', this.folders = const [], this.files = const [], this.summary = ''});
  final String url, path, zipUrl, code, message, summary;
  final bool connected, ok;
  final List<({String name, String path})> folders;
  final List<FolderFile> files;

  factory DropboxFolderListing.fromJson(Map<String, dynamic> j) => DropboxFolderListing(
        url: (j['url'] ?? '').toString(),
        path: (j['path'] ?? '').toString(),
        zipUrl: (j['zipUrl'] ?? '').toString(),
        connected: j['connected'] == true,
        ok: j['ok'] == true,
        code: (j['code'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        folders: [for (final f in (j['folders'] as List? ?? const [])) if (f is Map) (name: (f['name'] ?? '').toString(), path: (f['path'] ?? '').toString())],
        files: [for (final f in (j['files'] as List? ?? const [])) if (f is Map) FolderFile.fromJson(f.cast<String, dynamic>())],
      );
}

/// The same folder link as one .zip download (Dropbox's own "Download" on a shared folder) — '' when it is not a Dropbox folder link.
String dropboxFolderZipUrl(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || !(uri.host == 'dropbox.com' || uri.host == 'www.dropbox.com')) return '';
  final q = Map<String, String>.from(uri.queryParameters)..remove('raw')..['dl'] = '1';
  return Uri(scheme: 'https', host: uri.host, path: uri.path, queryParameters: q).toString();
}

class MediaStreamService {
  MediaStreamService(this._dio);
  final Dio? _dio;

  /// Addresses already given, by link — good for 11 hours (the server's last 12).
  final _given = <String, (DateTime, MediaStreamLink)>{};
  static const _keep = Duration(hours: 11);

  /// The server's stream address for the Dropbox video [url] — and with [probe], whether Dropbox will send it (asked of Dropbox; the
  /// server remembers the answer a while). Null when the server cannot help (an older server, offline, a link it does not play): the
  /// app then plays from Dropbox directly, as before.
  ///
  /// With [path]: the file at [path] inside the Dropbox FOLDER link [url] (the server reads it through its Dropbox app). A refusal the
  /// server explains (no Dropbox app, a kind of file the app cannot show) comes back as a link that is not [MediaStreamLink.ok].
  Future<MediaStreamLink?> link(String url, {bool probe = false, String path = ''}) async {
    final dio = _dio;
    if (dio == null) return null;
    final key = path.isEmpty ? url : '$url#$path';
    final hit = _given[key];
    if (!probe && hit != null && DateTime.now().difference(hit.$1) < _keep) return hit.$2;
    try {
      final res = await dio.get('/marketing/media/link', queryParameters: {'url': url, if (path.isNotEmpty) 'path': path, if (probe) 'probe': '1'});
      final body = res.data is Map ? (res.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
      final l = MediaStreamLink.fromJson(body, dio.options.baseUrl);
      // only an address Dropbox is not refusing is remembered (the server gives one either way)
      if (l.ok && l.url.isNotEmpty) _given[key] = (DateTime.now(), MediaStreamLink(url: l.url));
      return l;
    } on DioException catch (e) {
      // a file inside a folder the server will not open: its reason, in its words
      final data = e.response?.data;
      if (path.isNotEmpty && data is Map && (data['message'] ?? '').toString().isNotEmpty) {
        return MediaStreamLink(ok: false, code: (data['code'] ?? '').toString(), message: data['message'].toString());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// What is inside the Dropbox folder link [url] at [path] ('' = its top). Null when the server cannot be asked (offline, an older
  /// server): the folder then simply opens in Dropbox.
  Future<DropboxFolderListing?> folder(String url, {String path = '', bool fresh = false}) async {
    final dio = _dio;
    if (dio == null) return null;
    try {
      final res = await dio.get('/marketing/media/folder', queryParameters: {'url': url, if (path.isNotEmpty) 'path': path, if (fresh) 'fresh': '1'});
      final body = res.data is Map ? (res.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
      return DropboxFolderListing.fromJson(body);
    } catch (_) {
      return null;
    }
  }
}

/// A server that does not relay — tests, and anything with no server to ask.
class NoMediaStream extends MediaStreamService {
  NoMediaStream() : super(null);
  @override
  Future<MediaStreamLink?> link(String url, {bool probe = false, String path = ''}) async => null;
  @override
  Future<DropboxFolderListing?> folder(String url, {String path = '', bool fresh = false}) async => null;
}

final mediaStreamServiceProvider = Provider<MediaStreamService>((ref) => MediaStreamService(ref.watch(dioProvider)));
