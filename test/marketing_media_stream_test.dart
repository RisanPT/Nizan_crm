import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';

// Asking our server for a Dropbox video's stream address (media_stream.dart): the full address from the API base, the probe only when
// asked, the address remembered (not asked for again), and no answer — never an error — when the server cannot help.

class _Server implements HttpClientAdapter {
  _Server(this.answer);
  (int, Map<String, dynamic>)? answer;
  final asked = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    asked.add(options.uri);
    final a = answer;
    if (a == null) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    return ResponseBody.fromString(jsonEncode(a.$2), a.$1, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

MediaStreamService _service(_Server server, {String base = 'https://api.test/api/'}) => MediaStreamService(Dio(BaseOptions(baseUrl: base))..httpClientAdapter = server);

const _link = 'https://www.dropbox.com/scl/fi/abc/Reel.mp4?rlkey=K&dl=0';

void main() {
  test('the full address from the API base, whatever its trailing slash', () {
    expect(mediaStreamAddress('https://api.test/api/', '/marketing/media/stream/T'), 'https://api.test/api/marketing/media/stream/T');
    expect(mediaStreamAddress('https://api.test/api', 'marketing/media/stream/T'), 'https://api.test/api/marketing/media/stream/T');
  });

  test('the address is asked for once and remembered; a probe always asks (Dropbox\'s answer changes)', () async {
    final server = _Server((200, {'ok': true, 'path': '/marketing/media/stream/T.S', 'token': 'T.S'}));
    final s = _service(server);
    final a = await s.link(_link);
    expect(a!.url, 'https://api.test/api/marketing/media/stream/T.S');
    expect(a.ok, isTrue);
    expect(server.asked.single.queryParameters, {'url': _link}, reason: 'no probe asked for');
    expect(server.asked.single.path, '/api/marketing/media/link');
    expect((await s.link(_link))!.url, a.url);
    expect(server.asked, hasLength(1), reason: 'remembered');
    await s.link(_link, probe: true);
    expect(server.asked, hasLength(2));
    expect(server.asked.last.queryParameters['probe'], '1');
  });

  test('Dropbox\'s refusal comes back with its reason; a refusal is not remembered as an address', () async {
    final server = _Server((200, {'ok': false, 'code': 'limit', 'message': 'Paused.', 'retryDirect': false, 'path': '/marketing/media/stream/T.S'}));
    final s = _service(server);
    final r = await s.link(_link, probe: true);
    expect([r!.ok, r.code, r.message, r.retryDirect], [false, 'limit', 'Paused.', false]);
    final again = await s.link(_link);
    expect(again!.ok, isFalse, reason: 'the address alone is asked for again, not taken from the refusal');
    expect(server.asked, hasLength(2));
  });

  test('no help from the server — a link it will not play (400), offline, or no server at all — is no answer, never an error', () async {
    expect(await _service(_Server((400, {'code': 'not_playable', 'message': 'x'}))).link(_link), isNull);
    expect(await _service(_Server(null)).link(_link), isNull);
    expect(await NoMediaStream().link(_link, probe: true), isNull);
  });

  test('a direct Dropbox link in the answer is played first, while it has more than 5 minutes left; then the server\'s stream', () {
    final l = MediaStreamLink.fromJson({
      'path': '/marketing/media/stream/T0K.SIG',
      'ok': true,
      'direct': {'url': 'https://uc9.dl.dropboxusercontent.com/temp/reel.mp4', 'until': '2026-11-25T12:00:00.000Z'},
    }, 'https://api.test/api');
    expect(l.directUrl, 'https://uc9.dl.dropboxusercontent.com/temp/reel.mp4');
    final until = DateTime.parse('2026-11-25T12:00:00.000Z');
    expect(l.sourcesAt(until.subtract(const Duration(hours: 1))),
        ['https://uc9.dl.dropboxusercontent.com/temp/reel.mp4', 'https://api.test/api/marketing/media/stream/T0K.SIG']);
    expect(l.sourcesAt(until.subtract(const Duration(minutes: 4))), ['https://api.test/api/marketing/media/stream/T0K.SIG'],
        reason: 'about to stop working: the server\'s stream only');
    final plain = MediaStreamLink.fromJson({'path': '/marketing/media/stream/X.Y'}, 'https://api.test/api');
    expect(plain.directUrl, '');
    expect(plain.sources, ['https://api.test/api/marketing/media/stream/X.Y'], reason: 'someone else\'s link: the relay, as before');
  });
}
