// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_core.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ProjectCore _$ProjectCoreFromJson(Map<String, dynamic> json) {
  return _ProjectCore.fromJson(json);
}

/// @nodoc
mixin _$ProjectCore {
  String get serialNum => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Serializes this ProjectCore to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProjectCore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectCoreCopyWith<ProjectCore> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectCoreCopyWith<$Res> {
  factory $ProjectCoreCopyWith(
          ProjectCore value, $Res Function(ProjectCore) then) =
      _$ProjectCoreCopyWithImpl<$Res, ProjectCore>;
  @useResult
  $Res call({String serialNum, String name, String? description});
}

/// @nodoc
class _$ProjectCoreCopyWithImpl<$Res, $Val extends ProjectCore>
    implements $ProjectCoreCopyWith<$Res> {
  _$ProjectCoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProjectCore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? name = null,
    Object? description = freezed,
  }) {
    return _then(_value.copyWith(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProjectCoreImplCopyWith<$Res>
    implements $ProjectCoreCopyWith<$Res> {
  factory _$$ProjectCoreImplCopyWith(
          _$ProjectCoreImpl value, $Res Function(_$ProjectCoreImpl) then) =
      __$$ProjectCoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String serialNum, String name, String? description});
}

/// @nodoc
class __$$ProjectCoreImplCopyWithImpl<$Res>
    extends _$ProjectCoreCopyWithImpl<$Res, _$ProjectCoreImpl>
    implements _$$ProjectCoreImplCopyWith<$Res> {
  __$$ProjectCoreImplCopyWithImpl(
      _$ProjectCoreImpl _value, $Res Function(_$ProjectCoreImpl) _then)
      : super(_value, _then);

  /// Create a copy of ProjectCore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? name = null,
    Object? description = freezed,
  }) {
    return _then(_$ProjectCoreImpl(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ProjectCoreImpl implements _ProjectCore {
  const _$ProjectCoreImpl(
      {required this.serialNum, required this.name, this.description});

  factory _$ProjectCoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProjectCoreImplFromJson(json);

  @override
  final String serialNum;
  @override
  final String name;
  @override
  final String? description;

  @override
  String toString() {
    return 'ProjectCore(serialNum: $serialNum, name: $name, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectCoreImpl &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serialNum, name, description);

  /// Create a copy of ProjectCore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectCoreImplCopyWith<_$ProjectCoreImpl> get copyWith =>
      __$$ProjectCoreImplCopyWithImpl<_$ProjectCoreImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProjectCoreImplToJson(
      this,
    );
  }
}

abstract class _ProjectCore implements ProjectCore {
  const factory _ProjectCore(
      {required final String serialNum,
      required final String name,
      final String? description}) = _$ProjectCoreImpl;

  factory _ProjectCore.fromJson(Map<String, dynamic> json) =
      _$ProjectCoreImpl.fromJson;

  @override
  String get serialNum;
  @override
  String get name;
  @override
  String? get description;

  /// Create a copy of ProjectCore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectCoreImplCopyWith<_$ProjectCoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
