import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/routing/app_router.dart';
import 'package:nizan_crm/features/help/services/help_service.dart';

class HelpMsg {
  final bool user;
  final String text;
  final List<HelpLink> links;
  const HelpMsg(this.user, this.text, [this.links = const []]);
}

class HelpChatState {
  final List<HelpMsg> messages;
  final bool busy;
  const HelpChatState({this.messages = const [], this.busy = false});

  HelpChatState copyWith({List<HelpMsg>? messages, bool? busy}) =>
      HelpChatState(messages: messages ?? this.messages, busy: busy ?? this.busy);
}

/// The chat lives here, not in the panel, so closing the panel or navigating
/// to another screen keeps the conversation. It resets on "new chat" and when
/// a different user signs in.
final helpChatProvider =
    NotifierProvider<HelpChatController, HelpChatState>(HelpChatController.new);

class HelpChatController extends Notifier<HelpChatState> {
  List<HelpIndexEntry>? _index;

  @override
  HelpChatState build() {
    ref.watch(authSessionProvider.select((s) => s?.userId));
    _index = null;
    return const HelpChatState();
  }

  void clear() {
    if (!state.busy) state = const HelpChatState();
  }

  /// Manual entries this user may use, decided by the app's own route rules.
  Future<List<String>> _allowedIds() async {
    _index ??= await ref.read(helpServiceProvider).index();
    final session = ref.read(authSessionProvider);
    final access = Access.of(session);
    final inv = session?.inventoryAccess ?? false;
    final invManage = session?.inventoryManage ?? false;
    return [
      for (final e in _index!)
        if (e.gate == null ||
            isRouteAllowed(e.gate!, access,
                inventoryAccess: inv, inventoryManage: invManage))
          e.id
    ];
  }

  Future<void> send(String question) async {
    final q = question.trim();
    if (q.isEmpty || state.busy) return;
    final history = [
      for (final m in state.messages) (user: m.user, text: m.text)
    ];
    state = state.copyWith(
        messages: [...state.messages, HelpMsg(true, q)], busy: true);
    HelpMsg reply;
    try {
      final allowed = await _allowedIds();
      final a = await ref.read(helpServiceProvider).ask(q, allowed, history);
      reply = HelpMsg(false, a.text, a.links);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      reply = HelpMsg(
          false, msg ?? 'Could not reach the help service. Please try again.');
    } catch (_) {
      reply = const HelpMsg(false, 'Something went wrong. Please try again.');
    }
    state = state.copyWith(messages: [...state.messages, reply], busy: false);
  }
}
