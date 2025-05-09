// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tag_core.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TagCore _$TagCoreFromJson(Map<String, dynamic> json) {
  return _TagCore.fromJson(json);
}

/// @nodoc
mixin _$TagCore {
  @JsonKey(name: 'serial_num', required: true)
  String get serialNum => throw _privateConstructorUsedError;
  @JsonKey(name: 'name', required: true)
  String get name => throw _privateConstructorUsedError;

  /// Serializes this TagCore to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TagCore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TagCoreCopyWith<TagCore> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TagCoreCopyWith<$Res> {
  factory $TagCoreCopyWith(TagCore value, $Res Function(TagCore) then) =
      _$TagCoreCopyWithImpl<$Res, TagCore>;
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num', required: true) String serialNum,
      @JsonKey(name: 'name', required: true) String name});
}

/// @nodoc
class _$TagCoreCopyWithImpl<$Res, $Val extends TagCore>
    implements $TagCoreCopyWith<$Res> {
  _$TagCoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TagCore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? name = null,
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TagCoreImplCopyWith<$Res> implements $TagCoreCopyWith<$Res> {
  factory _$$TagCoreImplCopyWith(
          _$TagCoreImpl value, $Res Function(_$TagCoreImpl) then) =
      __$$TagCoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num', required: true) String serialNum,
      @JsonKey(name: 'name', required: true) String name});
}

/// @nodoc
class __$$TagCoreImplCopyWithImpl<$Res>
    extends _$TagCoreCopyWithImpl<$Res, _$TagCoreImpl>
    implements _$$TagCoreImplCopyWith<$Res> {
  __$$TagCoreImplCopyWithImpl(
      _$TagCoreImpl _value, $Res Function(_$TagCoreImpl) _then)
      : super(_value, _then);

  /// Create a copy of TagCore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? name = null,
  }) {
    return _then(_$TagCoreImpl(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TagCoreImpl implements _TagCore {
  const _$TagCoreImpl(
      {@JsonKey(name: 'serial_num', required: true) required this.serialNum,
      @JsonKey(name: 'name', required: true) required this.name});

  factory _$TagCoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$TagCoreImplFromJson(json);

  @override
  @JsonKey(name: 'serial_num', required: true)
  final String serialNum;
  @override
  @JsonKey(name: 'name', required: true)
  final String name;

  @override
  String toString() {
    return 'TagCore(serialNum: $serialNum, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TagCoreImpl &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serialNum, name);

  /// Create a copy of TagCore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TagCoreImplCopyWith<_$TagCoreImpl> get copyWith =>
      __$$TagCoreImplCopyWithImpl<_$TagCoreImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TagCoreImplToJson(
      this,
    );
  }
}

abstract class _TagCore implements TagCore {
  const factory _TagCore(
          {@JsonKey(name: 'serial_num', required: true)
          required final String serialNum,
          @JsonKey(name: 'name', required: true) required final String name}) =
      _$TagCoreImpl;

  factory _TagCore.fromJson(Map<String, dynamic> json) = _$TagCoreImpl.fromJson;

  @override
  @JsonKey(name: 'serial_num', required: true)
  String get serialNum;
  @override
  @JsonKey(name: 'name', required: true)
  String get name;

  /// Create a copy of TagCore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TagCoreImplCopyWith<_$TagCoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
