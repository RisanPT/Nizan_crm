// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(customerService)
final customerServiceProvider = CustomerServiceProvider._();

final class CustomerServiceProvider
    extends
        $FunctionalProvider<CustomerService, CustomerService, CustomerService>
    with $Provider<CustomerService> {
  CustomerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerServiceHash();

  @$internal
  @override
  $ProviderElement<CustomerService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CustomerService create(Ref ref) {
    return customerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerService>(value),
    );
  }
}

String _$customerServiceHash() => r'0f77edc75ac09f4a0b0478b332fa24f44f63e4e6';
