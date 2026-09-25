import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/it/data/ticket.dart';

final ticketServiceProvider = Provider((ref) => TicketService(ref.watch(dioProvider)));

/// Optional server-side filters for the ticket list.
class TicketQuery {
  final String? status;
  final String? type;
  final String? priority;
  final bool mine;
  final String? assignee;
  const TicketQuery({this.status, this.type, this.priority, this.mine = false, this.assignee});

  // Value equality is REQUIRED: this is a FutureProvider.family key. Without it,
  // every widget rebuild creates a new (unequal) key → a fresh provider that is
  // perpetually loading → the Help Desk list spins forever and never resolves.
  @override
  bool operator ==(Object other) =>
      other is TicketQuery &&
      other.status == status &&
      other.type == type &&
      other.priority == priority &&
      other.mine == mine &&
      other.assignee == assignee;

  @override
  int get hashCode => Object.hash(status, type, priority, mine, assignee);
}

/// Visibility-scoped ticket list (backend enforces "whole department + IT").
final ticketsProvider = FutureProvider.family<List<Ticket>, TicketQuery>(
    (ref, q) => ref.watch(ticketServiceProvider).getTickets(q));

/// A single ticket with its full activity thread.
final ticketProvider = FutureProvider.family<Ticket, String>(
    (ref, id) => ref.watch(ticketServiceProvider).getTicket(id));

/// IT dashboard counters.
final ticketStatsProvider = FutureProvider<Map<String, int>>(
    (ref) => ref.watch(ticketServiceProvider).getStats());

class TicketService {
  final Dio _dio;
  TicketService(this._dio);

  /// Runs an API call and rethrows any failure as an [AppException].
  Future<T> _guard<T>(String action, Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  Future<List<Ticket>> getTickets([TicketQuery q = const TicketQuery()]) => _guard('load tickets', () async {
        final res = await _dio.get('/tickets', queryParameters: {
          if (q.status != null && q.status!.isNotEmpty) 'status': q.status,
          if (q.type != null && q.type!.isNotEmpty) 'type': q.type,
          if (q.priority != null && q.priority!.isNotEmpty) 'priority': q.priority,
          if (q.mine) 'mine': 'true',
          if (q.assignee != null && q.assignee!.isNotEmpty) 'assignee': q.assignee,
        });
        return (res.data as List).map((e) => Ticket.fromJson((e as Map).cast<String, dynamic>())).toList();
      });

  Future<Ticket> _ticket(String action, Future<Response<dynamic>> Function() call) => _guard(action, () async {
        final res = await call();
        return Ticket.fromJson((res.data as Map).cast<String, dynamic>());
      });

  Future<Ticket> getTicket(String id) => _ticket('load the ticket', () => _dio.get('/tickets/$id'));

  Future<Ticket> createTicket(Map<String, dynamic> body) =>
      _ticket('raise the ticket', () => _dio.post('/tickets', data: body));

  Future<Ticket> updateTicket(String id, Map<String, dynamic> body) =>
      _ticket('update the ticket', () => _dio.put('/tickets/$id', data: body));

  Future<Ticket> addComment(String id, String text) =>
      _ticket('add the comment', () => _dio.post('/tickets/$id/comments', data: {'text': text}));

  Future<Ticket> promoteToTask(String id, Map<String, dynamic> body) =>
      _ticket('convert the ticket to a task', () => _dio.post('/tickets/$id/promote', data: body));

  Future<Map<String, int>> getStats() => _guard('load ticket stats', () async {
        final res = await _dio.get('/tickets/stats');
        final m = (res.data as Map).cast<String, dynamic>();
        return m.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
      });
}
