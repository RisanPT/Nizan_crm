import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

@freezed
abstract class Customer with _$Customer {
  factory Customer({
    @JsonKey(name: '_id') String? id,
    required String name,
    required String email,
    String? phone,
    String? company,
    @Default('Prospect') String status,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
}
