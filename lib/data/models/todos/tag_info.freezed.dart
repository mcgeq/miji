// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tag_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TagInfo {
  TagCore get core => throw _privateConstructorUsedError;

  /// Create a copy of TagInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TagInfoCopyWith<TagInfo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TagInfoCopyWith<$Res> {
  factory $TagInfoCopyWith(TagInfo value, $Res Function(TagInfo) then) =
      _$TagInfoCopyWithImpl<$Res, TagInfo>;
  @useResult
  $Res call({TagCore core});

  $TagCoreCopyWith<$Res> get core;
}

/// @nodoc
class _$TagInfoCopyWithImpl<$Res, $Val extends TagInfo>
    implements $TagInfoCopyWith<$Res> {
  _$TagInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TagInfo
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
              as TagCore,
    ) as $Val);
  }

  /// Create a copy of TagInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TagCoreCopyWith<$Res> get core {
    return $TagCoreCopyWith<$Res>(_value.core, (value) {
      return _then(_value.copyWith(core: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TagInfoImplCopyWith<$Res> implements $TagInfoCopyWith<$Res> {
  factory _$$TagInfoImplCopyWith(
          _$TagInfoImpl value, $Res Function(_$TagInfoImpl) then) =
      __$$TagInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({TagCore core});

  @override
  $TagCoreCopyWith<$Res> get core;
}

/// @nodoc
class __$$TagInfoImplCopyWithImpl<$Res>
    extends _$TagInfoCopyWithImpl<$Res, _$TagInfoImpl>
    implements _$$TagInfoImplCopyWith<$Res> {
  __$$TagInfoImplCopyWithImpl(
      _$TagInfoImpl _value, $Res Function(_$TagInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of TagInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? core = null,
  }) {
    return _then(_$TagInfoImpl(
      core: null == core
          ? _value.core
          : core // ignore: cast_nullable_to_non_nullable
              as TagCore,
    ));
  }
}

/// @nodoc

class _$TagInfoImpl extends _TagInfo {
  const _$TagInfoImpl({required this.core}) : super._();

  @override
  final TagCore core;

  @override
  String toString() {
    return 'TagInfo(core: $core)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TagInfoImpl &&
            (identical(other.core, core) || other.core == core));
  }

  @override
  int get hashCode => Object.hash(runtimeType, core);

  /// Create a copy of TagInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TagInfoImplCopyWith<_$TagInfoImpl> get copyWith =>
      __$$TagInfoImplCopyWithImpl<_$TagInfoImpl>(this, _$identity);
}

abstract class _TagInfo extends TagInfo {
  const factory _TagInfo({required final TagCore core}) = _$TagInfoImpl;
  const _TagInfo._() : super._();

  @override
  TagCore get core;

  /// Create a copy of TagInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TagInfoImplCopyWith<_$TagInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
