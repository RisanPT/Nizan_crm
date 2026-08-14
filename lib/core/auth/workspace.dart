import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../providers/auth_provider.dart';
import 'access_control.dart';
import 'app_role.dart';

/// A person can hold more than one job — an artist who also runs the studio
/// inventory. Rather than force a single role, such a user switches between
/// **workspaces**: their primary (artist) app and the inventory-manager app.
/// Everything else in the shell keys off the *effective* role for the active
/// workspace, so one login drives both experiences.
enum Workspace { primary, inventory }

/// True when [session] is a dual-role user — i.e. it carries the inventoryManage
/// capability on top of a non-manager primary role, so the workspace switcher
/// applies. A real `inventory_manager` role needs no switch (they're already it).
bool isDualRole(AuthSession? session) {
  if (session == null || !session.inventoryManage) return false;
  return AppRole.fromString(session.role) != AppRole.inventoryManager;
}

/// The role the shell should behave as, given the active [workspace].
/// Dual users in the inventory workspace resolve to [AppRole.inventoryManager];
/// everyone else keeps their primary role.
AppRole effectiveRole(AuthSession? session, Workspace workspace) {
  final base = session != null ? AppRole.fromString(session.role) : AppRole.artist;
  if (isDualRole(session) && workspace == Workspace.inventory) {
    return AppRole.inventoryManager;
  }
  return base;
}

/// The [Access] the shell should resolve for the active [workspace]. In the
/// inventory workspace a dual user gets the built-in inventory-manager matrix
/// (empty granted set → [Access] falls back to the role defaults); otherwise
/// their real session access is used unchanged.
Access effectiveAccess(AuthSession? session, Workspace workspace) {
  if (isDualRole(session) && workspace == Workspace.inventory) {
    return const Access(
      AppRole.inventoryManager,
      <String>{},
      configuredHomeRoute: '/inventory',
    );
  }
  return Access.of(session);
}

/// Per-user active workspace, persisted locally so the choice survives a
/// relaunch. Scoped to the user id so it never leaks across logins.
class WorkspaceNotifier extends Notifier<Workspace> {
  SharedPreferences? _prefs;
  String _userId = 'anon';

  String get _key => 'active_workspace_$_userId';

  @override
  Workspace build() {
    final session = ref.watch(authSessionProvider);
    _userId = session?.userId ?? 'anon';
    // A user who isn't dual-role can only ever be in their primary workspace —
    // guards against a stale persisted 'inventory' after the flag is revoked.
    if (!isDualRole(session)) return Workspace.primary;
    _load();
    return Workspace.primary;
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_key);
      if (raw == 'inventory') state = Workspace.inventory;
    } catch (_) {
      // No persistence — stay in the primary workspace.
    }
  }

  Future<void> set(Workspace workspace) async {
    state = workspace;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_key, workspace == Workspace.inventory ? 'inventory' : 'primary');
    } catch (_) {
      // Non-fatal — the in-memory switch still took effect for this session.
    }
  }

  void toggle() => set(state == Workspace.inventory ? Workspace.primary : Workspace.inventory);
}

final activeWorkspaceProvider =
    NotifierProvider<WorkspaceNotifier, Workspace>(WorkspaceNotifier.new);

/// True when the signed-in user can switch workspaces (dual-role).
final isDualRoleProvider = Provider<bool>((ref) {
  return isDualRole(ref.watch(authSessionProvider));
});

/// The role the shell should render for, honouring the active workspace.
final effectiveRoleProvider = Provider<AppRole>((ref) {
  final session = ref.watch(authSessionProvider);
  final workspace = ref.watch(activeWorkspaceProvider);
  return effectiveRole(session, workspace);
});

/// The [Access] the shell should resolve for, honouring the active workspace.
final effectiveAccessProvider = Provider<Access>((ref) {
  final session = ref.watch(authSessionProvider);
  final workspace = ref.watch(activeWorkspaceProvider);
  return effectiveAccess(session, workspace);
});
