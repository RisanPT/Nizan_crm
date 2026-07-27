// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BookingNotifier)
final bookingProvider = BookingNotifierProvider._();

final class BookingNotifierProvider
    extends $AsyncNotifierProvider<BookingNotifier, List<Booking>> {
  BookingNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingNotifierHash();

  @$internal
  @override
  BookingNotifier create() => BookingNotifier();
}

String _$bookingNotifierHash() => r'79e04558e77f27c2f065d9caddaf20401354c3cc';

abstract class _$BookingNotifier extends $AsyncNotifier<List<Booking>> {
  FutureOr<List<Booking>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Booking>>, List<Booking>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Booking>>, List<Booking>>,
              AsyncValue<List<Booking>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
