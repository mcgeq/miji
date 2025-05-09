// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'create_or_update_form.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CreateOrUpdateForm _$CreateOrUpdateFormFromJson(Map<String, dynamic> json) {
  return _CreateOrUpdateForm.fromJson(json);
}

/// @nodoc
mixin _$CreateOrUpdateForm {
  @JsonKey(name: 'serial_num')
  String? get serialNum => throw _privateConstructorUsedError;
  @JsonKey(name: 'name')
  String? get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'description')
  String? get description => throw _privateConstructorUsedError;

  /// Serializes this CreateOrUpdateForm to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CreateOrUpdateForm
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CreateOrUpdateFormCopyWith<CreateOrUpdateForm> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateOrUpdateFormCopyWith<$Res> {
  factory $CreateOrUpdateFormCopyWith(
          CreateOrUpdateForm value, $Res Function(CreateOrUpdateForm) then) =
      _$CreateOrUpdateFormCopyWithImpl<$Res, CreateOrUpdateForm>;
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num') String? serialNum,
      @JsonKey(name: 'name') String? name,
      @JsonKey(name: 'description') String? description});
}

/// @nodoc
class _$CreateOrUpdateFormCopyWithImpl<$Res, $Val extends CreateOrUpdateForm>
    implements $CreateOrUpdateFormCopyWith<$Res> {
  _$CreateOrUpdateFormCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CreateOrUpdateForm
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = freezed,
    Object? name = freezed,
    Object? description = freezed,
  }) {
    return _then(_value.copyWith(
      serialNum: freezed == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateOrUpdateFormImplCopyWith<$Res>
    implements $CreateOrUpdateFormCopyWith<$Res> {
  factory _$$CreateOrUpdateFormImplCopyWith(_$CreateOrUpdateFormImpl value,
          $Res Function(_$CreateOrUpdateFormImpl) then) =
      __$$CreateOrUpdateFormImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num') String? serialNum,
      @JsonKey(name: 'name') String? name,
      @JsonKey(name: 'description') String? description});
}

/// @nodoc
class __$$CreateOrUpdateFormImplCopyWithImpl<$Res>
    extends _$CreateOrUpdateFormCopyWithImpl<$Res, _$CreateOrUpdateFormImpl>
    implements _$$CreateOrUpdateFormImplCopyWith<$Res> {
  __$$CreateOrUpdateFormImplCopyWithImpl(_$CreateOrUpdateFormImpl _value,
      $Res Function(_$CreateOrUpdateFormImpl) _then)
      : super(_value, _then);

  /// Create a copy of CreateOrUpdateForm
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = freezed,
    Object? name = freezed,
    Object? description = freezed,
  }) {
    return _then(_$CreateOrUpdateFormImpl(
      serialNum: freezed == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CreateOrUpdateFormImpl implements _CreateOrUpdateForm {
  const _$CreateOrUpdateFormImpl(
      {@JsonKey(name: 'serial_num') this.serialNum,
      @JsonKey(name: 'name') this.name,
      @JsonKey(name: 'description') this.description});

  factory _$CreateOrUpdateFormImpl.fromJson(Map<String, dynamic> json) =>
      _$$CreateOrUpdateFormImplFromJson(json);

  @override
  @JsonKey(name: 'serial_num')
  final String? serialNum;
  @override
  @JsonKey(name: 'name')
  final String? name;
  @override
  @JsonKey(name: 'description')
  final String? description;

  @override
  String toString() {
    return 'CreateOrUpdateForm(serialNum: $serialNum, name: $name, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateOrUpdateFormImpl &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serialNum, name, description);

  /// Create a copy of CreateOrUpdateForm
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateOrUpdateFormImplCopyWith<_$CreateOrUpdateFormImpl> get copyWith =>
      __$$CreateOrUpdateFormImplCopyWithImpl<_$CreateOrUpdateFormImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CreateOrUpdateFormImplToJson(
      this,
    );
  }
}

abstract class _CreateOrUpdateForm implements CreateOrUpdateForm {
  const factory _CreateOrUpdateForm(
          {@JsonKey(name: 'serial_num') final String? serialNum,
          @JsonKey(name: 'name') final String? name,
          @JsonKey(name: 'description') final String? description}) =
      _$CreateOrUpdateFormImpl;

  factory _CreateOrUpdateForm.fromJson(Map<String, dynamic> json) =
      _$CreateOrUpdateFormImpl.fromJson;

  @override
  @JsonKey(name: 'serial_num')
  String? get serialNum;
  @override
  @JsonKey(name: 'name')
  String? get name;
  @override
  @JsonKey(name: 'description')
  String? get description;

  /// Create a copy of CreateOrUpdateForm
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CreateOrUpdateFormImplCopyWith<_$CreateOrUpdateFormImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
