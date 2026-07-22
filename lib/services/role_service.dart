import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';



/// An editable role and the feature keys granted to it.
class AppRoleRecord {
  final String id;
  final String key;
  final String label;
  final List<String> permissions;
  final String homeRoute;
  final bool isSystem;
  final bool active;
  final int userCount;

  const AppRoleRecord({
    required this.id,
    required this.key,
    required this.label,
    required this.permissions,
    required this.homeRoute,
    required this.isSystem,
    required this.active,
    required this.userCount,
  });

  factory AppRoleRecord.fromJson(Map<String, dynamic> json) {
    return AppRoleRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      permissions: ((json['permissions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      homeRoute: json['homeRoute'] as String? ?? '/',
      isSystem: json['isSystem'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      userCount: (json['userCount'] as num?)?.toInt() ?? 0,
    );
  }
}

final roleServiceProvider = Provider<RoleService>((ref) {
  return RoleService(ref.watch(dioProvider));
});

final rolesProvider = FutureProvider<List<AppRoleRecord>>((ref) async {
  return ref.watch(roleServiceProvider).getRoles();
});

class RoleService {
  final Dio _dio;
  RoleService(this._dio);

  Future<List<AppRoleRecord>> getRoles() async {
    final res = await _dio.get('/roles');
    return (res.data as List)
        .whereType<Map<String, dynamic>>()
        .map(AppRoleRecord.fromJson)
        .toList();
  }

  Future<void> createRole({
    required String label,
    required List<String> permissions,
    String homeRoute = '/',
  }) async {
    await _dio.post('/roles', data: {
      'label': label,
      'permissions': permissions,
      'homeRoute': homeRoute,
    });
  }

  Future<void> updateRole(
    String id, {
    String? label,
    List<String>? permissions,
    String? homeRoute,
    bool? active,
  }) async {
    await _dio.put('/roles/$id', data: {
      'label': ?label,
      'permissions': ?permissions,
      'homeRoute': ?homeRoute,
      'active': ?active,
    });
  }

  Future<void> deleteRole(String id) async {
    await _dio.delete('/roles/$id');
  }
}
