// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attachment_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AttachmentInfo _$AttachmentInfoFromJson(Map<String, dynamic> json) {
  return _AttachmentInfo.fromJson(json);
}

/// @nodoc
mixin _$AttachmentInfo {
  String get serialNum => throw _privateConstructorUsedError;
  String? get filePath => throw _privateConstructorUsedError;
  String? get url => throw _privateConstructorUsedError;

  /// Serializes this AttachmentInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttachmentInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttachmentInfoCopyWith<AttachmentInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttachmentInfoCopyWith<$Res> {
  factory $AttachmentInfoCopyWith(
          AttachmentInfo value, $Res Function(AttachmentInfo) then) =
      _$AttachmentInfoCopyWithImpl<$Res, AttachmentInfo>;
  @useResult
  $Res call({String serialNum, String? filePath, String? url});
}

/// @nodoc
class _$AttachmentInfoCopyWithImpl<$Res, $Val extends AttachmentInfo>
    implements $AttachmentInfoCopyWith<$Res> {
  _$AttachmentInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttachmentInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? filePath = freezed,
    Object? url = freezed,
  }) {
    return _then(_value.copyWith(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      filePath: freezed == filePath
          ? _value.filePath
          : filePath // ignore: cast_nullable_to_non_nullable
              as String?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AttachmentInfoImplCopyWith<$Res>
    implements $AttachmentInfoCopyWith<$Res> {
  factory _$$AttachmentInfoImplCopyWith(_$AttachmentInfoImpl value,
          $Res Function(_$AttachmentInfoImpl) then) =
      __$$AttachmentInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String serialNum, String? filePath, String? url});
}

/// @nodoc
class __$$AttachmentInfoImplCopyWithImpl<$Res>
    extends _$AttachmentInfoCopyWithImpl<$Res, _$AttachmentInfoImpl>
    implements _$$AttachmentInfoImplCopyWith<$Res> {
  __$$AttachmentInfoImplCopyWithImpl(
      _$AttachmentInfoImpl _value, $Res Function(_$AttachmentInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of AttachmentInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? filePath = freezed,
    Object? url = freezed,
  }) {
    return _then(_$AttachmentInfoImpl(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      filePath: freezed == filePath
          ? _value.filePath
          : filePath // ignore: cast_nullable_to_non_nullable
              as String?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AttachmentInfoImpl implements _AttachmentInfo {
  const _$AttachmentInfoImpl(
      {required this.serialNum, this.filePath, this.url});

  factory _$AttachmentInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttachmentInfoImplFromJson(json);

  @override
  final String serialNum;
  @override
  final String? filePath;
  @override
  final String? url;

  @override
  String toString() {
    return 'AttachmentInfo(serialNum: $serialNum, filePath: $filePath, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttachmentInfoImpl &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serialNum, filePath, url);

  /// Create a copy of AttachmentInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttachmentInfoImplCopyWith<_$AttachmentInfoImpl> get copyWith =>
      __$$AttachmentInfoImplCopyWithImpl<_$AttachmentInfoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttachmentInfoImplToJson(
      this,
    );
  }
}

abstract class _AttachmentInfo implements AttachmentInfo {
  const factory _AttachmentInfo(
      {required final String serialNum,
      final String? filePath,
      final String? url}) = _$AttachmentInfoImpl;

  factory _AttachmentInfo.fromJson(Map<String, dynamic> json) =
      _$AttachmentInfoImpl.fromJson;

  @override
  String get serialNum;
  @override
  String? get filePath;
  @override
  String? get url;

  /// Create a copy of AttachmentInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttachmentInfoImplCopyWith<_$AttachmentInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
