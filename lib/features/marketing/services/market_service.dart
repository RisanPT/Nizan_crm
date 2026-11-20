import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/market_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The active countries with their active cities — what the lead form picks from. Everybody signed in can read it.
final marketsProvider = FutureProvider<MarketList>((ref) async {
  final res = await ref.watch(dioProvider).get('/countries');
  return MarketList.fromJson(res.data);
});

/// The whole list for the Countries & Cities screen: the switched-off ones too, and how many leads sit in each (managers only —
/// anybody else gets the plain list from the server).
final marketsAllProvider = FutureProvider.autoDispose<MarketList>((ref) async {
  final res = await ref.watch(dioProvider).get('/countries', queryParameters: {'all': 1});
  return MarketList.fromJson(res.data);
});

/// Changes to the list. Every method refreshes both lists so the screen and the lead form agree; failures are thrown for the caller
/// to show (the server's message is already plain words — it comes through friendlyErrorMessage).
class MarketService {
  MarketService(this._ref);
  final Ref _ref;

  void _refresh() {
    _ref.invalidate(marketsProvider);
    _ref.invalidate(marketsAllProvider);
  }

  Future<void> addCountry({required String name, String code = '', String dialCode = '', String currency = ''}) async {
    await _ref.read(dioProvider).post('/countries', data: {'name': name, 'code': code, 'dialCode': dialCode, 'currency': currency});
    _refresh();
  }

  Future<void> updateCountry(String id, {required String name, String code = '', String dialCode = '', String currency = '', String? status}) async {
    await _ref.read(dioProvider).put('/countries/$id', data: {
      'name': name,
      'code': code,
      'dialCode': dialCode,
      'currency': currency,
      'status': ?status,
    });
    _refresh();
  }

  Future<void> deleteCountry(String id) async {
    await _ref.read(dioProvider).delete('/countries/$id');
    _refresh();
  }

  Future<void> addCity(String countryId, {required String name, String state = ''}) async {
    await _ref.read(dioProvider).post('/countries/$countryId/cities', data: {'name': name, 'state': state});
    _refresh();
  }

  Future<void> updateCity(String id, {required String name, String state = '', String? status}) async {
    await _ref.read(dioProvider).put('/countries/cities/$id', data: {'name': name, 'state': state, 'status': ?status});
    _refresh();
  }

  Future<void> deleteCity(String id) async {
    await _ref.read(dioProvider).delete('/countries/cities/$id');
    _refresh();
  }
}

final marketServiceProvider = Provider<MarketService>((ref) => MarketService(ref));
