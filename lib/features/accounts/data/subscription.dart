import 'package:nizan_crm/core/models/employee.dart';

class Subscription {
  final String id;
  final String name;
  final String department; // CRM | Finance | Accounts | IT | Sales | Marketing | HR | Operations | General
  final String plan;
  final double cost;
  final String billingCycle; // monthly | quarterly | yearly | one-time
  final String currency;
  final DateTime renewalDate;
  final String paymentMethod;
  final Employee? ownerEmployee;
  final String ownerName;
  final String status; // active | paused | cancelled | expired
  final bool autoRenew;
  final String websiteUrl;
  final String notes;
  final String receiptImage;
  final String? createdByName;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.name,
    required this.department,
    this.plan = '',
    required this.cost,
    required this.billingCycle,
    this.currency = 'INR',
    required this.renewalDate,
    this.paymentMethod = 'credit_card',
    this.ownerEmployee,
    this.ownerName = '',
    this.status = 'active',
    this.autoRenew = true,
    this.websiteUrl = '',
    this.notes = '',
    this.receiptImage = '',
    this.createdByName,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';

  int get daysUntilRenewal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(renewalDate.year, renewalDate.month, renewalDate.day);
    return target.difference(today).inDays;
  }

  bool get isRenewingSoon => daysUntilRenewal >= 0 && daysUntilRenewal <= 30 && isActive;
  bool get isOverdue => daysUntilRenewal < 0 && isActive;

  double get monthlyCostEquivalent {
    switch (billingCycle) {
      case 'monthly':
        return cost;
      case 'quarterly':
        return cost / 3;
      case 'yearly':
        return cost / 12;
      default:
        return cost / 12;
    }
  }

  double get annualCostEquivalent => monthlyCostEquivalent * 12;

  String get billingCycleLabel {
    switch (billingCycle) {
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      case 'one-time':
        return 'One-Time';
      default:
        return billingCycle;
    }
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['ownerEmployeeId'];
    final createdByJson = json['createdBy'];

    return Subscription(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Software Tool',
      department: json['department'] as String? ?? 'IT',
      plan: json['plan'] as String? ?? '',
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      billingCycle: json['billingCycle'] as String? ?? 'monthly',
      currency: json['currency'] as String? ?? 'INR',
      renewalDate: DateTime.tryParse(json['renewalDate']?.toString() ?? '') ?? DateTime.now(),
      paymentMethod: json['paymentMethod'] as String? ?? 'credit_card',
      ownerEmployee: ownerJson is Map<String, dynamic>
          ? Employee.fromJson(ownerJson)
          : null,
      ownerName: json['ownerName'] as String? ??
          (ownerJson is Map<String, dynamic> ? (ownerJson['name'] as String? ?? '') : ''),
      status: json['status'] as String? ?? 'active',
      autoRenew: json['autoRenew'] as bool? ?? true,
      websiteUrl: json['websiteUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      receiptImage: json['receiptImage'] as String? ?? '',
      createdByName: createdByJson is Map<String, dynamic>
          ? createdByJson['name'] as String?
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
      'plan': plan,
      'cost': cost,
      'billingCycle': billingCycle,
      'currency': currency,
      'renewalDate': renewalDate.toIso8601String(),
      'paymentMethod': paymentMethod,
      if (ownerEmployee != null) 'ownerEmployeeId': ownerEmployee!.id,
      'ownerName': ownerName,
      'status': status,
      'autoRenew': autoRenew,
      'websiteUrl': websiteUrl,
      'notes': notes,
      'receiptImage': receiptImage,
    };
  }
}
