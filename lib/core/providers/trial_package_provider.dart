import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import '../../services/trial_package_service.dart';
import '../models/trial_package.dart';



final trialPackageServiceProvider = Provider<TrialPackageService>((ref) {
  return TrialPackageService(ref.watch(dioProvider));
});

final trialPackagesProvider = FutureProvider<List<TrialPackage>>((ref) async {
  final service = ref.read(trialPackageServiceProvider);
  return await service.getTrialPackages();
});
