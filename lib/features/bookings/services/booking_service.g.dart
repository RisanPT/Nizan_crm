// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookingService)
final bookingServiceProvider = BookingServiceProvider._();

final class BookingServiceProvider
    extends $FunctionalProvider<BookingService, BookingService, BookingService>
    with $Provider<BookingService> {
  BookingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingServiceHash();

  @$internal
  @override
  $ProviderElement<BookingService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookingService create(Ref ref) {
    return bookingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookingService>(value),
    );
  }
}

String _$bookingServiceHash() => r'f6e94bceff21bc7f1142f9069b90450d5e419b67';
