// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TodoInput _$TodoInputFromJson(Map<String, dynamic> json) {
  return _TodoInput.fromJson(json);
}

/// @nodoc
mixin _$TodoInput {
  String? get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime? get dueAt => throw _privateConstructorUsedError;
  Priority? get priority => throw _privateConstructorUsedError;
  Status? get status => throw _privateConstructorUsedError;
  List<CreateOrUpdateForm>? get tags => throw _privateConstructorUsedError;
  String? get repeat => throw _privateConstructorUsedError;
  int? get progress => throw _privateConstructorUsedError;
  String? get assigneeId => throw _privateConstructorUsedError;
  List<CreateOrUpdateForm>? get projects => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  String? get ownerId => throw _privateConstructorUsedError;

  /// Serializes this TodoInput to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TodoInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TodoInputCopyWith<TodoInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TodoInputCopyWith<$Res> {
  factory $TodoInputCopyWith(TodoInput value, $Res Function(TodoInput) then) =
      _$TodoInputCopyWithImpl<$Res, TodoInput>;
  @useResult
  $Res call(
      {String? title,
      String? description,
      @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      DateTime? dueAt,
      Priority? priority,
      Status? status,
      List<CreateOrUpdateForm>? tags,
      String? repeat,
      int? progress,
      String? assigneeId,
      List<CreateOrUpdateForm>? projects,
      String? location,
      String? ownerId});
}

/// @nodoc
class _$TodoInputCopyWithImpl<$Res, $Val extends TodoInput>
    implements $TodoInputCopyWith<$Res> {
  _$TodoInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TodoInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
    Object? description = freezed,
    Object? dueAt = freezed,
    Object? priority = freezed,
    Object? status = freezed,
    Object? tags = freezed,
    Object? repeat = freezed,
    Object? progress = freezed,
    Object? assigneeId = freezed,
    Object? projects = freezed,
    Object? location = freezed,
    Object? ownerId = freezed,
  }) {
    return _then(_value.copyWith(
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      dueAt: freezed == dueAt
          ? _value.dueAt
          : dueAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: freezed == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as Priority?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as Status?,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<CreateOrUpdateForm>?,
      repeat: freezed == repeat
          ? _value.repeat
          : repeat // ignore: cast_nullable_to_non_nullable
              as String?,
      progress: freezed == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int?,
      assigneeId: freezed == assigneeId
          ? _value.assigneeId
          : assigneeId // ignore: cast_nullable_to_non_nullable
              as String?,
      projects: freezed == projects
          ? _value.projects
          : projects // ignore: cast_nullable_to_non_nullable
              as List<CreateOrUpdateForm>?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TodoInputImplCopyWith<$Res>
    implements $TodoInputCopyWith<$Res> {
  factory _$$TodoInputImplCopyWith(
          _$TodoInputImpl value, $Res Function(_$TodoInputImpl) then) =
      __$$TodoInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? title,
      String? description,
      @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      DateTime? dueAt,
      Priority? priority,
      Status? status,
      List<CreateOrUpdateForm>? tags,
      String? repeat,
      int? progress,
      String? assigneeId,
      List<CreateOrUpdateForm>? projects,
      String? location,
      String? ownerId});
}

/// @nodoc
class __$$TodoInputImplCopyWithImpl<$Res>
    extends _$TodoInputCopyWithImpl<$Res, _$TodoInputImpl>
    implements _$$TodoInputImplCopyWith<$Res> {
  __$$TodoInputImplCopyWithImpl(
      _$TodoInputImpl _value, $Res Function(_$TodoInputImpl) _then)
      : super(_value, _then);

  /// Create a copy of TodoInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
    Object? description = freezed,
    Object? dueAt = freezed,
    Object? priority = freezed,
    Object? status = freezed,
    Object? tags = freezed,
    Object? repeat = freezed,
    Object? progress = freezed,
    Object? assigneeId = freezed,
    Object? projects = freezed,
    Object? location = freezed,
    Object? ownerId = freezed,
  }) {
    return _then(_$TodoInputImpl(
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      dueAt: freezed == dueAt
          ? _value.dueAt
          : dueAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: freezed == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as Priority?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as Status?,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<CreateOrUpdateForm>?,
      repeat: freezed == repeat
          ? _value.repeat
          : repeat // ignore: cast_nullable_to_non_nullable
              as String?,
      progress: freezed == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int?,
      assigneeId: freezed == assigneeId
          ? _value.assigneeId
          : assigneeId // ignore: cast_nullable_to_non_nullable
              as String?,
      projects: freezed == projects
          ? _value._projects
          : projects // ignore: cast_nullable_to_non_nullable
              as List<CreateOrUpdateForm>?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TodoInputImpl implements _TodoInput {
  const _$TodoInputImpl(
      {this.title,
      this.description,
      @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson) this.dueAt,
      this.priority,
      this.status,
      final List<CreateOrUpdateForm>? tags,
      this.repeat,
      this.progress,
      this.assigneeId,
      final List<CreateOrUpdateForm>? projects,
      this.location,
      this.ownerId})
      : _tags = tags,
        _projects = projects;

  factory _$TodoInputImpl.fromJson(Map<String, dynamic> json) =>
      _$$TodoInputImplFromJson(json);

  @override
  final String? title;
  @override
  final String? description;
  @override
  @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime? dueAt;
  @override
  final Priority? priority;
  @override
  final Status? status;
  final List<CreateOrUpdateForm>? _tags;
  @override
  List<CreateOrUpdateForm>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? repeat;
  @override
  final int? progress;
  @override
  final String? assigneeId;
  final List<CreateOrUpdateForm>? _projects;
  @override
  List<CreateOrUpdateForm>? get projects {
    final value = _projects;
    if (value == null) return null;
    if (_projects is EqualUnmodifiableListView) return _projects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? location;
  @override
  final String? ownerId;

  @override
  String toString() {
    return 'TodoInput(title: $title, description: $description, dueAt: $dueAt, priority: $priority, status: $status, tags: $tags, repeat: $repeat, progress: $progress, assigneeId: $assigneeId, projects: $projects, location: $location, ownerId: $ownerId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TodoInputImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.dueAt, dueAt) || other.dueAt == dueAt) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.repeat, repeat) || other.repeat == repeat) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.assigneeId, assigneeId) ||
                other.assigneeId == assigneeId) &&
            const DeepCollectionEquality().equals(other._projects, _projects) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      title,
      description,
      dueAt,
      priority,
      status,
      const DeepCollectionEquality().hash(_tags),
      repeat,
      progress,
      assigneeId,
      const DeepCollectionEquality().hash(_projects),
      location,
      ownerId);

  /// Create a copy of TodoInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TodoInputImplCopyWith<_$TodoInputImpl> get copyWith =>
      __$$TodoInputImplCopyWithImpl<_$TodoInputImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TodoInputImplToJson(
      this,
    );
  }
}

abstract class _TodoInput implements TodoInput {
  const factory _TodoInput(
      {final String? title,
      final String? description,
      @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      final DateTime? dueAt,
      final Priority? priority,
      final Status? status,
      final List<CreateOrUpdateForm>? tags,
      final String? repeat,
      final int? progress,
      final String? assigneeId,
      final List<CreateOrUpdateForm>? projects,
      final String? location,
      final String? ownerId}) = _$TodoInputImpl;

  factory _TodoInput.fromJson(Map<String, dynamic> json) =
      _$TodoInputImpl.fromJson;

  @override
  String? get title;
  @override
  String? get description;
  @override
  @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime? get dueAt;
  @override
  Priority? get priority;
  @override
  Status? get status;
  @override
  List<CreateOrUpdateForm>? get tags;
  @override
  String? get repeat;
  @override
  int? get progress;
  @override
  String? get assigneeId;
  @override
  List<CreateOrUpdateForm>? get projects;
  @override
  String? get location;
  @override
  String? get ownerId;

  /// Create a copy of TodoInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TodoInputImplCopyWith<_$TodoInputImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
