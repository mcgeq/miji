// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ProjectInfo {
  ProjectCore get core => throw _privateConstructorUsedError;

  /// Create a copy of ProjectInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectInfoCopyWith<ProjectInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectInfoCopyWith<$Res> {
  factory $ProjectInfoCopyWith(
          ProjectInfo value, $Res Function(ProjectInfo) then) =
      _$ProjectInfoCopyWithImpl<$Res, ProjectInfo>;
  @useResult
  $Res call({ProjectCore core});

  $ProjectCoreCopyWith<$Res> get core;
}

/// @nodoc
class _$ProjectInfoCopyWithImpl<$Res, $Val extends ProjectInfo>
    implements $ProjectInfoCopyWith<$Res> {
  _$ProjectInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProjectInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? core = null,
  }) {
    return _then(_value.copyWith(
      core: null == core
          ? _value.core
          : core // ignore: cast_nullable_to_non_nullable
              as ProjectCore,
    ) as $Val);
  }

  /// Create a copy of ProjectInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProjectCoreCopyWith<$Res> get core {
    return $ProjectCoreCopyWith<$Res>(_value.core, (value) {
      return _then(_value.copyWith(core: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ProjectInfoImplCopyWith<$Res>
    implements $ProjectInfoCopyWith<$Res> {
  factory _$$ProjectInfoImplCopyWith(
          _$ProjectInfoImpl value, $Res Function(_$ProjectInfoImpl) then) =
      __$$ProjectInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ProjectCore core});

  @override
  $ProjectCoreCopyWith<$Res> get core;
}

/// @nodoc
class __$$ProjectInfoImplCopyWithImpl<$Res>
    extends _$ProjectInfoCopyWithImpl<$Res, _$ProjectInfoImpl>
    implements _$$ProjectInfoImplCopyWith<$Res> {
  __$$ProjectInfoImplCopyWithImpl(
      _$ProjectInfoImpl _value, $Res Function(_$ProjectInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ProjectInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? core = null,
  }) {
    return _then(_$ProjectInfoImpl(
      core: null == core
          ? _value.core
          : core // ignore: cast_nullable_to_non_nullable
              as ProjectCore,
    ));
  }
}

/// @nodoc

class _$ProjectInfoImpl extends _ProjectInfo {
  const _$ProjectInfoImpl({required this.core}) : super._();

  @override
  final ProjectCore core;

  @override
  String toString() {
    return 'ProjectInfo(core: $core)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectInfoImpl &&
            (identical(other.core, core) || other.core == core));
  }

  @override
  int get hashCode => Object.hash(runtimeType, core);

  /// Create a copy of ProjectInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectInfoImplCopyWith<_$ProjectInfoImpl> get copyWith =>
      __$$ProjectInfoImplCopyWithImpl<_$ProjectInfoImpl>(this, _$identity);
}

abstract class _ProjectInfo extends ProjectInfo {
  const factory _ProjectInfo({required final ProjectCore core}) =
      _$ProjectInfoImpl;
  const _ProjectInfo._() : super._();

  @override
  ProjectCore get core;

  /// Create a copy of ProjectInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectInfoImplCopyWith<_$ProjectInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
