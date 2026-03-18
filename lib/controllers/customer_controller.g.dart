// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CustomerController)
final customerControllerProvider = CustomerControllerProvider._();

final class CustomerControllerProvider
    extends $AsyncNotifierProvider<CustomerController, List<Customer>> {
  CustomerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerControllerHash();

  @$internal
  @override
  CustomerController create() => CustomerController();
}

String _$customerControllerHash() =>
    r'7fe8103d1a19637de990ba924b52b5826c9aef74';

abstract class _$CustomerController extends $AsyncNotifier<List<Customer>> {
  FutureOr<List<Customer>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Customer>>, List<Customer>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Customer>>, List<Customer>>,
              AsyncValue<List<Customer>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
