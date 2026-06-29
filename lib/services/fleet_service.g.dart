// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fleet_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fleetService)
final fleetServiceProvider = FleetServiceProvider._();

final class FleetServiceProvider
    extends $FunctionalProvider<FleetService, FleetService, FleetService>
    with $Provider<FleetService> {
  FleetServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fleetServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fleetServiceHash();

  @$internal
  @override
  $ProviderElement<FleetService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FleetService create(Ref ref) {
    return fleetService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FleetService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FleetService>(value),
    );
  }
}

String _$fleetServiceHash() => r'f352b1cdb8849a574ca525c92c1685a32749e8b6';

@ProviderFor(driverJobs)
final driverJobsProvider = DriverJobsProvider._();

final class DriverJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FleetJob>>,
          List<FleetJob>,
          FutureOr<List<FleetJob>>
        >
    with $FutureModifier<List<FleetJob>>, $FutureProvider<List<FleetJob>> {
  DriverJobsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driverJobsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driverJobsHash();

  @$internal
  @override
  $FutureProviderElement<List<FleetJob>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FleetJob>> create(Ref ref) {
    return driverJobs(ref);
  }
}

String _$driverJobsHash() => r'8300aa4d99c5f5c63f6971e907959de305f8bf8b';

@ProviderFor(managerReviews)
final managerReviewsProvider = ManagerReviewsProvider._();

final class ManagerReviewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DriverReview>>,
          List<DriverReview>,
          FutureOr<List<DriverReview>>
        >
    with
        $FutureModifier<List<DriverReview>>,
        $FutureProvider<List<DriverReview>> {
  ManagerReviewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managerReviewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managerReviewsHash();

  @$internal
  @override
  $FutureProviderElement<List<DriverReview>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DriverReview>> create(Ref ref) {
    return managerReviews(ref);
  }
}

String _$managerReviewsHash() => r'dc7490699e2dc152bcb7c990ec73687ad0db49c9';

@ProviderFor(managerAccidents)
final managerAccidentsProvider = ManagerAccidentsProvider._();

final class ManagerAccidentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AccidentReport>>,
          List<AccidentReport>,
          FutureOr<List<AccidentReport>>
        >
    with
        $FutureModifier<List<AccidentReport>>,
        $FutureProvider<List<AccidentReport>> {
  ManagerAccidentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managerAccidentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managerAccidentsHash();

  @$internal
  @override
  $FutureProviderElement<List<AccidentReport>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AccidentReport>> create(Ref ref) {
    return managerAccidents(ref);
  }
}

String _$managerAccidentsHash() => r'a027c952d116606ad86cb552716bd207ff00b7e9';

@ProviderFor(managerCompletedWorks)
final managerCompletedWorksProvider = ManagerCompletedWorksProvider._();

final class ManagerCompletedWorksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FleetJob>>,
          List<FleetJob>,
          FutureOr<List<FleetJob>>
        >
    with $FutureModifier<List<FleetJob>>, $FutureProvider<List<FleetJob>> {
  ManagerCompletedWorksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managerCompletedWorksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managerCompletedWorksHash();

  @$internal
  @override
  $FutureProviderElement<List<FleetJob>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FleetJob>> create(Ref ref) {
    return managerCompletedWorks(ref);
  }
}

String _$managerCompletedWorksHash() =>
    r'5c296e3e0240b426ff65ab22571550a55d9e0abd';

@ProviderFor(managerServiceReminders)
final managerServiceRemindersProvider = ManagerServiceRemindersProvider._();

final class ManagerServiceRemindersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServiceReminder>>,
          List<ServiceReminder>,
          FutureOr<List<ServiceReminder>>
        >
    with
        $FutureModifier<List<ServiceReminder>>,
        $FutureProvider<List<ServiceReminder>> {
  ManagerServiceRemindersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managerServiceRemindersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managerServiceRemindersHash();

  @$internal
  @override
  $FutureProviderElement<List<ServiceReminder>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ServiceReminder>> create(Ref ref) {
    return managerServiceReminders(ref);
  }
}

String _$managerServiceRemindersHash() =>
    r'61b77198a309ec16788b8ff1f57c1c5330543bd5';
