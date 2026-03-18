import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';

part 'customer_controller.g.dart';

@riverpod
class CustomerController extends _$CustomerController {
  @override
  FutureOr<List<Customer>> build() async {
    return _fetchCustomers();
  }

  Future<List<Customer>> _fetchCustomers() async {
    return await ref.read(customerServiceProvider).getCustomers();
  }
  
  // Example of how you would implement a method that updates state
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCustomers());
  }
}
