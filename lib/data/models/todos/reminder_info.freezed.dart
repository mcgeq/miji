// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reminder_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ReminderInfo _$ReminderInfoFromJson(Map<String, dynamic> json) {
  return _ReminderInfo.fromJson(json);
}

/// @nodoc
mixin _$ReminderInfo {
  @JsonKey(name: 'serial_num', required: true)
  String get serialNum => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'remind_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime get remindAt => throw _privateConstructorUsedError;

  /// Serializes this ReminderInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReminderInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReminderInfoCopyWith<ReminderInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReminderInfoCopyWith<$Res> {
  factory $ReminderInfoCopyWith(
          ReminderInfo value, $Res Function(ReminderInfo) then) =
      _$ReminderInfoCopyWithImpl<$Res, ReminderInfo>;
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num', required: true) String serialNum,
      @JsonKey(
          name: 'remind_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      DateTime remindAt});
}

/// @nodoc
class _$ReminderInfoCopyWithImpl<$Res, $Val extends ReminderInfo>
    implements $ReminderInfoCopyWith<$Res> {
  _$ReminderInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReminderInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? remindAt = null,
  }) {
    return _then(_value.copyWith(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      remindAt: null == remindAt
          ? _value.remindAt
          : remindAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReminderInfoImplCopyWith<$Res>
    implements $ReminderInfoCopyWith<$Res> {
  factory _$$ReminderInfoImplCopyWith(
          _$ReminderInfoImpl value, $Res Function(_$ReminderInfoImpl) then) =
      __$$ReminderInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num', required: true) String serialNum,
      @JsonKey(
          name: 'remind_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      DateTime remindAt});
}

/// @nodoc
class __$$ReminderInfoImplCopyWithImpl<$Res>
    extends _$ReminderInfoCopyWithImpl<$Res, _$ReminderInfoImpl>
    implements _$$ReminderInfoImplCopyWith<$Res> {
  __$$ReminderInfoImplCopyWithImpl(
      _$ReminderInfoImpl _value, $Res Function(_$ReminderInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReminderInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? remindAt = null,
  }) {
    return _then(_$ReminderInfoImpl(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      remindAt: null == remindAt
          ? _value.remindAt
          : remindAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReminderInfoImpl implements _ReminderInfo {
  const _$ReminderInfoImpl(
      {@JsonKey(name: 'serial_num', required: true) required this.serialNum,
      @JsonKey(
          name: 'remind_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      required this.remindAt});

  factory _$ReminderInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReminderInfoImplFromJson(json);

  @override
  @JsonKey(name: 'serial_num', required: true)
  final String serialNum;
  @override
  @JsonKey(
      name: 'remind_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime remindAt;

  @override
  String toString() {
    return 'ReminderInfo(serialNum: $serialNum, remindAt: $remindAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReminderInfoImpl &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.remindAt, remindAt) ||
                other.remindAt == remindAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serialNum, remindAt);

  /// Create a copy of ReminderInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReminderInfoImplCopyWith<_$ReminderInfoImpl> get copyWith =>
      __$$ReminderInfoImplCopyWithImpl<_$ReminderInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReminderInfoImplToJson(
      this,
    );
  }
}

abstract class _ReminderInfo implements ReminderInfo {
  const factory _ReminderInfo(
      {@JsonKey(name: 'serial_num', required: true)
      required final String serialNum,
      @JsonKey(
          name: 'remind_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      required final DateTime remindAt}) = _$ReminderInfoImpl;

  factory _ReminderInfo.fromJson(Map<String, dynamic> json) =
      _$ReminderInfoImpl.fromJson;

  @override
  @JsonKey(name: 'serial_num', required: true)
  String get serialNum;
  @override
  @JsonKey(
      name: 'remind_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime get remindAt;

  /// Create a copy of ReminderInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReminderInfoImplCopyWith<_$ReminderInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
