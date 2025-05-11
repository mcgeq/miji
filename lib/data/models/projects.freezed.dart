// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'projects.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Projects {
  @JsonKey(name: 'description')
  String? get description;
  @JsonKey(name: 'name')
  String get name;
  @JsonKey(name: 'serial_num')
  String get serialNum;

  /// Create a copy of Projects
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProjectsCopyWith<Projects> get copyWith =>
      _$ProjectsCopyWithImpl<Projects>(this as Projects, _$identity);

  /// Serializes this Projects to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Projects &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, description, name, serialNum);

  @override
  String toString() {
    return 'Projects(description: $description, name: $name, serialNum: $serialNum)';
  }
}

/// @nodoc
abstract mixin class $ProjectsCopyWith<$Res> {
  factory $ProjectsCopyWith(Projects value, $Res Function(Projects) _then) =
      _$ProjectsCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'description') String? description,
      @JsonKey(name: 'name') String name,
      @JsonKey(name: 'serial_num') String serialNum});
}

/// @nodoc
class _$ProjectsCopyWithImpl<$Res> implements $ProjectsCopyWith<$Res> {
  _$ProjectsCopyWithImpl(this._self, this._then);

  final Projects _self;
  final $Res Function(Projects) _then;

  /// Create a copy of Projects
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? description = freezed,
    Object? name = null,
    Object? serialNum = null,
  }) {
    return _then(_self.copyWith(
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      serialNum: null == serialNum
          ? _self.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Projects implements Projects {
  const _Projects(
      {@JsonKey(name: 'description') this.description = null,
      @JsonKey(name: 'name') required this.name,
      @JsonKey(name: 'serial_num') required this.serialNum});
  factory _Projects.fromJson(Map<String, dynamic> json) =>
      _$ProjectsFromJson(json);

  @override
  @JsonKey(name: 'description')
  final String? description;
  @override
  @JsonKey(name: 'name')
  final String name;
  @override
  @JsonKey(name: 'serial_num')
  final String serialNum;

  /// Create a copy of Projects
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProjectsCopyWith<_Projects> get copyWith =>
      __$ProjectsCopyWithImpl<_Projects>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProjectsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Projects &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, description, name, serialNum);

  @override
  String toString() {
    return 'Projects(description: $description, name: $name, serialNum: $serialNum)';
  }
}

/// @nodoc
abstract mixin class _$ProjectsCopyWith<$Res>
    implements $ProjectsCopyWith<$Res> {
  factory _$ProjectsCopyWith(_Projects value, $Res Function(_Projects) _then) =
      __$ProjectsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'description') String? description,
      @JsonKey(name: 'name') String name,
      @JsonKey(name: 'serial_num') String serialNum});
}

/// @nodoc
class __$ProjectsCopyWithImpl<$Res> implements _$ProjectsCopyWith<$Res> {
  __$ProjectsCopyWithImpl(this._self, this._then);

  final _Projects _self;
  final $Res Function(_Projects) _then;

  /// Create a copy of Projects
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? description = freezed,
    Object? name = null,
    Object? serialNum = null,
  }) {
    return _then(_Projects(
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      serialNum: null == serialNum
          ? _self.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
