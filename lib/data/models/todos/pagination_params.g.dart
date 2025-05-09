// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pagination_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaginationParamsImpl _$$PaginationParamsImplFromJson(
    Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['page', 'page_size'],
  );
  return _$PaginationParamsImpl(
    page: (json['page'] as num?)?.toInt(),
    pageSize: (json['page_size'] as num?)?.toInt(),
  );
}

Map<String, dynamic> _$$PaginationParamsImplToJson(
        _$PaginationParamsImpl instance) =>
    <String, dynamic>{
      'page': instance.page,
      'page_size': instance.pageSize,
    };
