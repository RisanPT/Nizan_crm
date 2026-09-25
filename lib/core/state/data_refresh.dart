// ════════════════════════════════════════════════════════════════════════════
// One place that knows every provider holding each kind of data.
//
// WHY: most list/detail providers cache their data until invalidated. Screens
// often watch a DIFFERENT provider than the one a save invalidated (e.g. the
// Services list reads `paginatedPackagesProvider` but adding a package only
// invalidated `packagesProvider`), so the screen kept showing stale data until
// a full page reload. Some data is even exposed by two providers with the same
// name in different files (vehicles, bank accounts).
//
// RULE: after ANY successful add / edit / delete / status change, call the
// matching refresher instead of hand-picking providers:
//
//     await service.saveBooking(...);
//     ref.refreshData.bookings();     // WidgetRef or Ref — both work
//
// Each refresher also refreshes the data that the change affects elsewhere
// (a booking changes clients, slot availability, dashboards…). When you add a
// new provider, register it in the matching function below.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

// Core / shared
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/my_department_provider.dart';
import 'package:nizan_crm/core/providers/trial_package_provider.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/services/addon_service_service.dart';
import 'package:nizan_crm/services/blocked_date_service.dart';
import 'package:nizan_crm/services/customer_service.dart';
import 'package:nizan_crm/controllers/customer_controller.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/services/lead_activity_service.dart';
import 'package:nizan_crm/services/package_service.dart';
import 'package:nizan_crm/services/pincode_service.dart';
import 'package:nizan_crm/services/region_service.dart';
import 'package:nizan_crm/services/role_service.dart';
import 'package:nizan_crm/services/state_service.dart';
import 'package:nizan_crm/services/user_service.dart';
import 'package:nizan_crm/services/zone_service.dart';
import 'package:nizan_crm/services/vehicle_service.dart' as legacy_vehicles;

// Sales / bookings / slots / reviews / notifications
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/slots/services/slot_service.dart';
import 'package:nizan_crm/features/reviews/services/review_service.dart';
import 'package:nizan_crm/features/notifications/controllers/notification_providers.dart';

// Accounts
import 'package:nizan_crm/features/accounts/controllers/account_report_provider.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/budget_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_filters_provider.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/hra_provider.dart';
import 'package:nizan_crm/features/accounts/controllers/salary_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/sales_return_provider.dart';
import 'package:nizan_crm/features/accounts/controllers/subscription_controller.dart';
import 'package:nizan_crm/features/accounts/services/artist_payout_service.dart';
import 'package:nizan_crm/features/accounts/services/expense_category_service.dart';

// Finance
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart' as acc;
import 'package:nizan_crm/features/finance/controllers/asset_provider.dart';
import 'package:nizan_crm/features/finance/controllers/sales_report_provider.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart' as bank;
import 'package:nizan_crm/features/finance/services/month_end_service.dart';
import 'package:nizan_crm/features/finance/services/tax_filing_service.dart';

// Fleet / HR / org / inventory
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart' as fleet_vehicles;
import 'package:nizan_crm/features/hr/service/evaluation_service.dart';
import 'package:nizan_crm/features/hr/service/timebox_service.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';

// IT / marketing / reports
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';
import 'package:nizan_crm/features/it/services/ticket_service.dart';
import 'package:nizan_crm/features/marketing/services/campaign_service.dart';
import 'package:nizan_crm/features/marketing/services/content_service.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';
import 'package:nizan_crm/features/marketing/services/marketing_service.dart';
import 'package:nizan_crm/features/reports/services/company_report_service.dart';
import 'package:nizan_crm/features/reports/services/financial_report_service.dart';

typedef _Invalidate = void Function(ProviderOrFamily provider);

void _all(_Invalidate inv, List<ProviderOrFamily> providers) {
  for (final p in providers) {
    inv(p);
  }
}

/// The refreshers, shared by [WidgetRef] and [Ref] via the extensions below.
class DataRefresh {
  DataRefresh._(this._inv, this._bump);
  final _Invalidate _inv;
  final void Function(StateProvider<int>) _bump;

  // ── Clients / sales ───────────────────────────────────────────────────────

  void customers() => _all(_inv, [
        customersProvider,
        paginatedCustomersProvider,
        clientDirectoryProvider,
        clientStatsProvider,
        customerControllerProvider,
      ]);

  void leads() {
    _all(_inv, [
      leadsProvider,
      paginatedLeadsProvider,
      leadClustersProvider,
      leadReportProvider,
      leadActivitiesProvider,
    ]);
  }

  /// A booking changes clients (auto-created), slot availability, calendars,
  /// artist works, invoices/collections views and sales reports.
  void bookings() {
    _bump(bookingsRefreshTriggerProvider);
    _all(_inv, [
      bookingProvider,
      paginatedBookingsProvider,
      singleBookingProvider,
      artistAssignedWorksProvider,
      bookingCalendarProvider,
      salesReportProvider,
    ]);
    customers();
    slots();
    leads(); // booking a lead converts it
  }

  void trials() {
    _bump(trialsRefreshTriggerProvider);
    _all(_inv, [
      trialsProvider,
      allTrialsProvider,
      artistTrialsProvider,
      singleTrialProvider,
    ]);
  }

  void trialPackages() => _inv(trialPackagesProvider);

  void packages() => _all(_inv, [packagesProvider, paginatedPackagesProvider]);

  void addonServices() =>
      _all(_inv, [addonServicesProvider, paginatedAddonServicesProvider]);

  void slots() => _all(_inv, [
        monthAvailabilityProvider,
        slotDefaultsProvider,
        blockedDatesProvider,
      ]);

  void reviews() => _all(_inv, [
        reviewsProvider,
        reviewAnalyticsProvider,
        artistReviewPerformanceProvider,
      ]);

  void notifications() => _all(_inv, [notificationsProvider, unreadCountProvider]);

  // ── People / org / geography ─────────────────────────────────────────────

  void employees() => _all(_inv, [
        employeesProvider,
        paginatedEmployeesProvider,
        activeEmployeesProvider,
        itEmployeesProvider,
        departmentEmployeesProvider,
        projectEmployeesProvider,
        departmentMembersProvider,
        timeboxEmployeesProvider,
        currentEmployeeProvider,
      ]);

  void crmUsers() {
    _all(_inv, [crmUsersProvider, paginatedCrmUsersProvider]);
    employees(); // users and employees are kept in sync server-side
  }

  void roles() => _inv(rolesProvider);

  void departments() => _all(_inv, [
        departmentsProvider,
        departmentsListProvider,
        departmentMembersProvider,
        myDepartmentNameProvider,
      ]);

  void geography() => _all(_inv, [
        zonesProvider,
        paginatedZonesProvider,
        statesProvider,
        paginatedStatesProvider,
        regionsProvider,
        paginatedRegionsProvider,
        districtsProvider,
        paginatedDistrictsProvider,
        pincodesProvider,
        paginatedPincodesProvider,
      ]);

  void hr() => _all(_inv, [
        evaluationsProvider,
        employeeEvaluationsProvider,
        periodAttendanceProvider,
        attendanceSummaryProvider,
        employeeAttendanceProvider,
        employeeDaysProvider,
        payrollPreviewProvider,
        // NOT timeboxMonthProvider: that's the user's selected month.
      ]);

  // ── Money (accounts) — every one also moves the finance reports ──────────

  void collections() {
    _all(_inv, [
      collectionsProvider,
      artistCollectionsProvider,
      filteredCollectionsProvider,
    ]);
    financeReports();
    bookings(); // payment status / balances shown on bookings & invoices
  }

  void expenses() {
    _all(_inv, [
      expensesProvider,
      artistExpensesProvider,
      adminExpensesProvider,
      adminExpenseStatsProvider,
      currentBudgetProvider, // budget usage
    ]);
    financeReports();
  }

  void expenseCategories() => _inv(expenseCategoriesProvider);

  void salaries() {
    _all(_inv, [
      salariesProvider,
      adminSalariesProvider,
      opsSalariesProvider,
    ]);
    financeReports();
  }

  void payouts() {
    _all(_inv, [artistPayoutsProvider, artistPayoutsForEmployeeProvider]);
    financeReports();
  }

  void hra() {
    _all(_inv, [hraRecordsProvider, hraStatsProvider]);
    expenses(); // the backend mirrors each HRA record into an admin expense
    notifications();
  }

  void salesReturns() {
    _all(_inv, [salesReturnsProvider, salesReturnStatsProvider]);
    financeReports();
    notifications(); // returns notify roles server-side
  }

  void subscriptions() {
    _all(_inv, [subscriptionsProvider, subscriptionStatsProvider]);
    financeReports();
  }

  void budget() => _inv(currentBudgetProvider);

  void accountReports() => _inv(accountReportsProvider);

  // ── Finance ──────────────────────────────────────────────────────────────

  /// Ledger-derived statements. Called by every money-moving refresher.
  void financeReports() => _all(_inv, [
        acc.journalEntriesProvider,
        acc.ledgerProvider,
        acc.trialBalanceProvider,
        acc.profitLossProvider,
        acc.balanceSheetProvider,
        acc.agingProvider,
        acc.partyStatementProvider,
        acc.gstSummaryProvider,
        acc.gstr1Provider,
        acc.reconciliationProvider,
        acc.bankAccountsProvider,
        bank.bankAccountsProvider,
        salesReportProvider,
        monthEndReviewProvider,
        departmentReportProvider,
        financialAnalystReportProvider,
      ]);

  void chartOfAccounts() {
    _inv(acc.chartAccountsProvider);
    financeReports();
  }

  void accountingSettings() => _all(_inv, [
        acc.accountingSettingsProvider,
        acc.gstSettingsProvider,
      ]);

  void bankAccounts() {
    _all(_inv, [acc.bankAccountsProvider, bank.bankAccountsProvider]);
    financeReports();
  }

  void assets() {
    _all(_inv, [
      assetsProvider,
      assetStatsProvider,
      depreciationRunsProvider,
      depreciationScheduleProvider,
    ]);
    financeReports();
  }

  void taxFilings() => _inv(taxFilingBoardProvider);

  void monthEnd() => _all(_inv, [
        monthEndReviewProvider,
        monthlyTargetProvider,
        decisionsProvider,
        openDecisionsProvider,
        departmentReportProvider,
      ]);

  // ── Fleet ────────────────────────────────────────────────────────────────

  void vehicles() => _all(_inv, [
        fleet_vehicles.vehiclesProvider,
        fleet_vehicles.paginatedVehiclesProvider,
        legacy_vehicles.vehiclesProvider,
        legacy_vehicles.paginatedVehiclesProvider,
        managerServiceRemindersProvider,
      ]);

  void fuelExpenses() {
    _all(_inv, [fuelExpensesProvider, paginatedFuelExpensesProvider]);
    financeReports();
  }

  void fleetJobs() => _all(_inv, [
        driverJobsProvider,
        managerCompletedWorksProvider,
        managerAccidentsProvider,
        managerReviewsProvider,
        managerServiceRemindersProvider,
      ]);

  // ── Inventory ────────────────────────────────────────────────────────────

  void inventory() => _all(_inv, [
        inventoryProductsProvider,
        staffKitsProvider,
      ]);

  /// Purchases add stock AND are vendor bills (finance).
  void purchases() {
    _all(_inv, [purchasesProvider, vendorsProvider]);
    inventory();
    financeReports();
  }

  void vendors() => _inv(vendorsProvider);

  // ── IT ───────────────────────────────────────────────────────────────────

  void projects() => _all(_inv, [
        projectsProvider,
        itProjectsProvider,
        companyProjectsProvider,
        projectEmployeesProvider,
      ]);

  void tasks() => _all(_inv, [tasksProvider, allTasksProvider, myTasksProvider]);

  void okrs() => _all(_inv, [projectOKRsProvider, planningOkrsProvider]);

  void tickets() => _all(_inv, [ticketsProvider, ticketStatsProvider, ticketProvider]);

  // ── Marketing / reports ─────────────────────────────────────────────────

  void campaigns() => _inv(campaignsProvider);

  void content() => _all(_inv, [contentByMonthProvider, contentStatsProvider]);

  void competitors() => _all(_inv, [
        competitorsProvider,
        rankingsProvider,
        scoringConfigProvider,
      ]);

  void marketingInsights() => _all(_inv, [
        marketingInsightsProvider,
        reEngagementProvider,
        bookingCalendarProvider,
      ]);

  void companyReports() => _all(_inv, [
        companyReportsProvider,
        reportFoldersProvider,
        teamReportsProvider,
      ]);
}

extension DataRefreshWidgetRef on WidgetRef {
  /// `ref.refreshData.bookings()` — see [DataRefresh].
  DataRefresh get refreshData => DataRefresh._(
        invalidate,
        (p) => read(p.notifier).state++,
      );
}

extension DataRefreshRef on Ref {
  DataRefresh get refreshData => DataRefresh._(
        invalidate,
        (p) => read(p.notifier).state++,
      );
}
