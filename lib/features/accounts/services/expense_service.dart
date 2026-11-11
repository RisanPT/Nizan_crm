import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';

class ExpenseService {
  final Dio _dio;

  ExpenseService(this._dio);

  /// ACCOUNTS: one filtered, sorted page of artist expenses with totals for the whole
  /// filtered set (the server does the filtering and paging).
  Future<FinancePage<ArtistExpense>> getExpensePage(FinanceQuery query) async {
    try {
      final response = await _dio.get('/expenses', queryParameters: query.toParams());
      return FinancePage.fromJson(response.data as Map<String, dynamic>, ArtistExpense.fromJson);
    } catch (e) {
      throw AppException(e, action: 'load expenses');
    }
  }

  /// Every expense matching [query] (the server caps it), for the export.
  Future<FinanceExport<ArtistExpense>> exportExpenses(FinanceQuery query) async {
    try {
      final response = await _dio.get('/expenses', queryParameters: query.toParams(export: true));
      return FinanceExport.fromJson(response.data as Map<String, dynamic>, ArtistExpense.fromJson);
    } catch (e) {
      throw AppException(e, action: 'export expenses');
    }
  }

  Future<List<ArtistExpense>> getExpenses({
    String? status,
    String? employeeId,
    String? bookingId,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (status != null) query['status'] = status;
      if (employeeId != null) query['employeeId'] = employeeId;
      if (bookingId != null) query['bookingId'] = bookingId;

      final response = await _dio.get(
        '/expenses',
        queryParameters: query.isNotEmpty ? query : null,
      );
      final data = response.data as List;
      return data
          .map((item) => ArtistExpense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load expenses');
    }
  }

  Future<ArtistExpense> createExpense({
    required String employeeId,
    String? bookingId,
    required String category,
    required double amount,
    required DateTime date,
    String notes = '',
    String receiptImage = '',
    String workType = 'bridal',
    String meal = '',
    List<String> meals = const [],
  }) async {
    try {
      // One bill can cover several meals: [meals] says which, [meal] is the single one ('' when
      // there are two or more). A caller giving only [meal] is the same as meals: [meal].
      final covered = mealFields(meals.isNotEmpty ? meals : [if (meal.isNotEmpty) meal]);
      final hasMeal = covered.meals.isNotEmpty;
      final payload = {
        'employeeId': employeeId,
        if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
        'category': category,
        'workType': workType,
        if (hasMeal) ...{'meal': covered.meal, 'meals': covered.meals},
        'amount': amount,
        // A food expense carries the TIME of the meal; sent as an exact instant so the server
        // places it on the right IST day and between the right works.
        'date': (hasMeal ? date.toUtc() : date).toIso8601String(),
        'notes': notes,
        'receiptImage': receiptImage,
      };
      final response = await _dio.post('/expenses', data: payload);
      return ArtistExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create expense');
    }
  }

  /// Edits an existing expense. The backend rejects this for an artist once
  /// Accounts has verified or rejected the entry.
  Future<ArtistExpense> updateExpense({
    required String id,
    String? bookingId,
    String? category,
    double? amount,
    DateTime? date,
    String? notes,
    String? receiptImage,
    String? workType,
    String? meal,
    List<String>? meals,
  }) async {
    try {
      // [meals] (one or several) wins over [meal]; both empty = not a meal entry, which clears them.
      final covered = meals != null ? mealFields(meals) : (meal != null ? mealFields([if (meal.isNotEmpty) meal]) : null);
      final hasMeal = covered != null && covered.meals.isNotEmpty;
      final response = await _dio.put('/expenses/$id', data: {
        'workType': ?workType,
        'bookingId': ?bookingId,
        'category': ?category,
        if (covered != null) ...{'meal': covered.meal, 'meals': covered.meals},
        'amount': ?amount,
        'date': ?(hasMeal ? date?.toUtc() : date)?.toIso8601String(),
        'notes': ?notes,
        'receiptImage': ?receiptImage,
      });
      return ArtistExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update expense');
    }
  }

  /// While adding a meal: which of the artist's works that day it would be counted under.
  /// Accounts, adding on an artist's behalf, names the artist in [employeeId].
  ///
  /// [meal] is one meal, or several written with commas ("breakfast,lunch,dinner") — what the
  /// preview provider's key carries; [meals] is the same as a list. One meal is asked for as
  /// `meal=`, two or more as `meals=`.
  Future<MealPreview> getMealPreview({required DateTime at, String meal = '', List<String> meals = const [], String? employeeId, String? bookingId, String? excludeId}) async {
    try {
      final asked = orderMeals(meals.isNotEmpty ? meals : meal.split(',').map((m) => m.trim()));
      final response = await _dio.get('/expenses/meal-preview', queryParameters: {
        'at': at.toUtc().toIso8601String(),
        if (asked.length > 1) 'meals': asked.join(',') else 'meal': asked.isEmpty ? meal : asked.first,
        'employeeId': ?employeeId,
        'bookingId': ?bookingId,
        'excludeId': ?excludeId,
      });
      return MealPreview.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'check which work this meal is for');
    }
  }

  /// One artist's day as a timeline: their works in order, the costs under each.
  Future<ArtistDay> getArtistDay({required String employeeId, required String day}) async {
    try {
      final response = await _dio.get('/expenses/artist-day', queryParameters: {'employeeId': employeeId, 'day': day});
      return ArtistDay.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: "load the artist's day");
    }
  }

  /// Cost per work over a period (Accounts).
  Future<WorkCostPage> getWorkCosts(WorkCostQuery query) async {
    try {
      final response = await _dio.get('/expenses/work-costs', queryParameters: query.toParams());
      return WorkCostPage.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the cost per work');
    }
  }

  /// Every work matching [query], with its lines, for the export (the server caps it).
  Future<WorkCostPage> exportWorkCosts(WorkCostQuery query) async {
    try {
      final response = await _dio.get('/expenses/work-costs', queryParameters: query.toParams(export: true));
      return WorkCostPage.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'export the cost per work');
    }
  }

  Future<ArtistExpense> verifyExpense({
    required String id,
    required String status, // 'verified' | 'rejected'
    required String verifiedBy,
    MoneyChoice? money, // which account paid it back (approval popup)
  }) async {
    try {
      final response = await _dio.put(
        '/expenses/$id/verify',
        data: {'status': status, 'verifiedBy': verifiedBy, ...?money?.toJson()},
      );
      return ArtistExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'verify expense');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _dio.delete('/expenses/$id');
    } catch (e) {
      throw AppException(e, action: 'delete expense');
    }
  }
}
