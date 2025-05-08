// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo_id.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TodoId _$TodoIdFromJson(Map<String, dynamic> json) {
  return _TodoId.fromJson(json);
}

/// @nodoc
mixin _$TodoId {
  String get serialNum => throw _privateConstructorUsedError;

  /// Serializes this TodoId to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TodoId
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TodoIdCopyWith<TodoId> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TodoIdCopyWith<$Res> {
  factory $TodoIdCopyWith(TodoId value, $Res Function(TodoId) then) =
      _$TodoIdCopyWithImpl<$Res, TodoId>;
  @useResult
  $Res call({String serialNum});
}

/// @nodoc
class _$TodoIdCopyWithImpl<$Res, $Val extends TodoId>
    implements $TodoIdCopyWith<$Res> {
  _$TodoIdCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TodoId
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
  }) {
    return _then(_value.copyWith(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TodoIdImplCopyWith<$Res> implements $TodoIdCopyWith<$Res> {
  factory _$$TodoIdImplCopyWith(
          _$TodoIdImpl value, $Res Function(_$TodoIdImpl) then) =
      __$$TodoIdImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String serialNum});
}

/// @nodoc
class __$$TodoIdImplCopyWithImpl<$Res>
    extends _$TodoIdCopyWithImpl<$Res, _$TodoIdImpl>
    implements _$$TodoIdImplCopyWith<$Res> {
  __$$TodoIdImplCopyWithImpl(
      _$TodoIdImpl _value, $Res Function(_$TodoIdImpl) _then)
      : super(_value, _then);

  /// Create a copy of TodoId
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
  }) {
    return _then(_$TodoIdImpl(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TodoIdImpl implements _TodoId {
  const _$TodoIdImpl({required this.serialNum});

  factory _$TodoIdImpl.fromJson(Map<String, dynamic> json) =>
      _$$TodoIdImplFromJson(json);

  @override
  final String serialNum;

  @override
  String toString() {
    return 'TodoId(serialNum: $serialNum)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TodoIdImpl &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serialNum);

  /// Create a copy of TodoId
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TodoIdImplCopyWith<_$TodoIdImpl> get copyWith =>
      __$$TodoIdImplCopyWithImpl<_$TodoIdImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TodoIdImplToJson(
      this,
    );
  }
}

abstract class _TodoId implements TodoId {
  const factory _TodoId({required final String serialNum}) = _$TodoIdImpl;

  factory _TodoId.fromJson(Map<String, dynamic> json) = _$TodoIdImpl.fromJson;

  @override
  String get serialNum;

  /// Create a copy of TodoId
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TodoIdImplCopyWith<_$TodoIdImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
