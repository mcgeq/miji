// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projects.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Projects _$ProjectsFromJson(Map<String, dynamic> json) => _Projects(
      description: json['description'] as String? ?? null,
      name: json['name'] as String,
      serialNum: json['serial_num'] as String,
    );

Map<String, dynamic> _$ProjectsToJson(_Projects instance) => <String, dynamic>{
      'description': instance.description,
      'name': instance.name,
      'serial_num': instance.serialNum,
    };
