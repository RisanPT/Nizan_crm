// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Customer _$CustomerFromJson(Map<String, dynamic> json) => _Customer(
  id: json['_id'] as String?,
  name: json['name'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String?,
  address: json['address'] as String?,
  pincode: json['pincode'] as String?,
  company: json['company'] as String?,
  status: json['status'] as String? ?? 'Prospect',
);

Map<String, dynamic> _$CustomerToJson(_Customer instance) => <String, dynamic>{
  '_id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'address': instance.address,
  'pincode': instance.pincode,
  'company': instance.company,
  'status': instance.status,
};
