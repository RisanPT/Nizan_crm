import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/workspace.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/crm_theme.dart';

/// Human label for a workspace.
String workspaceLabel(Workspace w) =>
    w == Workspace.inventory ? 'Inventory Manager' : 'Artist';

IconData workspaceIcon(Workspace w) =>
    w == Workspace.inventory ? Icons.inventory_2_outlined : Icons.brush_outlined;

/// Flip a dual-role user into [target] and land them on that workspace's home.
/// The active workspace only decides which shell renders; backend access is the
/// union of both roles, so the destination is always reachable.
void switchToWorkspace(BuildContext context, WidgetRef ref, Workspace target) {
  ref.read(activeWorkspaceProvider.notifier).set(target);
  final session = ref.read(authSessionProvider);
  final access = effectiveAccess(session, target);
  final dest = landingRouteFor(
    access,
    inventoryAccess: session?.inventoryAccess ?? false,
    inventoryManage: session?.inventoryManage ?? false,
  );
  context.go(dest);
}

/// App-bar action (mobile shell): a swap icon that toggles the workspace.
/// Renders nothing unless the signed-in user is dual-role.
class WorkspaceSwitchAction extends ConsumerWidget {
  const WorkspaceSwitchAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isDualRoleProvider)) return const SizedBox.shrink();
    final current = ref.watch(activeWorkspaceProvider);
    final other = current == Workspace.inventory ? Workspace.primary : Workspace.inventory;
    return IconButton(
      icon: const Icon(Icons.swap_horiz_rounded),
      tooltip: 'Switch to ${workspaceLabel(other)}',
      onPressed: () => switchToWorkspace(context, ref, other),
    );
  }
}

/// A tappable row that switches to the *other* workspace — for the desktop
/// sidebar and the mobile menu sheets. Renders nothing for non-dual users.
class WorkspaceSwitchTile extends ConsumerWidget {
  const WorkspaceSwitchTile({super.key, this.collapsed = false, this.onTap});

  /// When true (collapsed sidebar), shows only the icon.
  final bool collapsed;

  /// Optional extra callback (e.g. pop a bottom sheet) run before switching.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isDualRoleProvider)) return const SizedBox.shrink();
    final crm = context.crmColors;
    final current = ref.watch(activeWorkspaceProvider);
    final other = current == Workspace.inventory ? Workspace.primary : Workspace.inventory;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap?.call();
          switchToWorkspace(context, ref, other);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 11),
          decoration: BoxDecoration(
            color: crm.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crm.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(Icons.swap_horiz_rounded, size: 20, color: crm.primary),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Switch workspace',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: crm.textSecondary)),
                      Text('Go to ${workspaceLabel(other)}',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: crm.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(workspaceIcon(other), size: 18, color: crm.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
