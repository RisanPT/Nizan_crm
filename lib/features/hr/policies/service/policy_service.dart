import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/policy_models.dart';

class HrPolicyNotifier extends Notifier<List<HrPolicy>> {
  @override
  List<HrPolicy> build() {
    return kDefaultCompanyPolicies;
  }

  void acknowledgePolicy(String policyId, String employeeId) {
    state = state.map((p) {
      if (p.id == policyId && !p.acknowledgedBy.contains(employeeId)) {
        return p.copyWith(acknowledgedBy: [...p.acknowledgedBy, employeeId]);
      }
      return p;
    }).toList();
  }

  void addPolicy(HrPolicy policy) {
    state = [policy, ...state];
  }

  void updatePolicy(HrPolicy updated) {
    state = state.map((p) => p.id == updated.id ? updated : p).toList();
  }
}

final hrPoliciesProvider = NotifierProvider<HrPolicyNotifier, List<HrPolicy>>(
  HrPolicyNotifier.new,
);
