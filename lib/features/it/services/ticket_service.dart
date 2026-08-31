import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<List<Ticket>> getTickets([TicketQuery q = const TicketQuery()]) async {
    final res = await _dio.get('/tickets', queryParameters: {
      if (q.status != null && q.status!.isNotEmpty) 'status': q.status,
      if (q.type != null && q.type!.isNotEmpty) 'type': q.type,
      if (q.priority != null && q.priority!.isNotEmpty) 'priority': q.priority,
      if (q.mine) 'mine': 'true',
      if (q.assignee != null && q.assignee!.isNotEmpty) 'assignee': q.assignee,
    });
    return (res.data as List).map((e) => Ticket.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Ticket> getTicket(String id) async {
    final res = await _dio.get('/tickets/$id');
    return Ticket.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<Ticket> createTicket(Map<String, dynamic> body) async {
    final res = await _dio.post('/tickets', data: body);
    return Ticket.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<Ticket> updateTicket(String id, Map<String, dynamic> body) async {
    final res = await _dio.put('/tickets/$id', data: body);
    return Ticket.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<Ticket> addComment(String id, String text) async {
    final res = await _dio.post('/tickets/$id/comments', data: {'text': text});
    return Ticket.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<Ticket> promoteToTask(String id, Map<String, dynamic> body) async {
    final res = await _dio.post('/tickets/$id/promote', data: body);
    return Ticket.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<Map<String, int>> getStats() async {
    final res = await _dio.get('/tickets/stats');
    final m = (res.data as Map).cast<String, dynamic>();
    return m.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  }
}
