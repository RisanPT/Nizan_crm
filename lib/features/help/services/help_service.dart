import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';

final helpServiceProvider =
    Provider<HelpService>((ref) => HelpService(ref.watch(dioProvider)));

/// A manual entry's id and the route whose permission decides who may see it
/// (null = everyone).
class HelpIndexEntry {
  final String id;
  final String? gate;
  const HelpIndexEntry(this.id, this.gate);
}

class HelpLink {
  final String id;
  final String title;
  final String? route;
  final String menuPath;
  final String? inPage;
  const HelpLink(this.id, this.title, this.route, this.menuPath, this.inPage);
}

class HelpAnswer {
  final String text;
  final List<HelpLink> links;
  const HelpAnswer(this.text, this.links);
}

/// Talks to /api/help. The backend only reads the user manual — no business
/// data is sent or returned.
class HelpService {
  final Dio _dio;
  HelpService(this._dio);

  Future<List<HelpIndexEntry>> index() async {
    final res = await _dio.get('/help/index');
    return (res.data as List)
        .map((e) => HelpIndexEntry(e['id'] as String, e['gate'] as String?))
        .toList();
  }

  Future<HelpAnswer> ask(
    String question,
    List<String> allowedIds,
    List<({bool user, String text})> history,
  ) async {
    final res = await _dio.post('/help/ask', data: {
      'question': question,
      'allowedIds': allowedIds,
      'history': [
        for (final h in history)
          {'role': h.user ? 'user' : 'assistant', 'text': h.text}
      ],
    });
    final data = (res.data as Map).cast<String, dynamic>();
    final links = ((data['links'] as List?) ?? const [])
        .map((l) => HelpLink(l['id'] as String, l['title'] as String,
            l['route'] as String?, (l['menuPath'] as String?) ?? '',
            l['inPage'] as String?))
        .toList();
    return HelpAnswer(data['answer'] as String? ?? '', links);
  }
}
