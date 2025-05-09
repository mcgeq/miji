// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TodoResponse _$TodoResponseFromJson(Map<String, dynamic> json) {
  return _TodoResponse.fromJson(json);
}

/// @nodoc
mixin _$TodoResponse {
  @JsonKey(name: 'serial_num', required: true)
  String get serialNum => throw _privateConstructorUsedError;
  @JsonKey(name: 'title', required: true)
  String get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'description')
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime get dueAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
  Priority get priority => throw _privateConstructorUsedError;
  @JsonKey(fromJson: Status.fromJson, toJson: statusToJson)
  Status get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'repeat')
  String? get repeat => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'completed_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime? get completedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'assignee_id')
  String? get assigneeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'progress', required: true)
  int get progress => throw _privateConstructorUsedError;
  @JsonKey(name: 'location')
  String? get location => throw _privateConstructorUsedError;
  @JsonKey(name: 'owner_id')
  String? get ownerId => throw _privateConstructorUsedError;
  @JsonKey(name: 'projects', required: true)
  List<ProjectInfo> get projects => throw _privateConstructorUsedError;
  @JsonKey(name: 'tags', required: true)
  List<TagInfo> get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'reminders', required: true)
  List<ReminderInfo> get reminders => throw _privateConstructorUsedError;
  @JsonKey(name: 'attachments', required: true)
  List<AttachmentInfo> get attachments => throw _privateConstructorUsedError;

  /// Serializes this TodoResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TodoResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TodoResponseCopyWith<TodoResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TodoResponseCopyWith<$Res> {
  factory $TodoResponseCopyWith(
          TodoResponse value, $Res Function(TodoResponse) then) =
      _$TodoResponseCopyWithImpl<$Res, TodoResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num', required: true) String serialNum,
      @JsonKey(name: 'title', required: true) String title,
      @JsonKey(name: 'description') String? description,
      @JsonKey(
          name: 'created_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      DateTime? updatedAt,
      @JsonKey(
          name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      DateTime dueAt,
      @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
      Priority priority,
      @JsonKey(fromJson: Status.fromJson, toJson: statusToJson) Status status,
      @JsonKey(name: 'repeat') String? repeat,
      @JsonKey(
          name: 'completed_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      DateTime? completedAt,
      @JsonKey(name: 'assignee_id') String? assigneeId,
      @JsonKey(name: 'progress', required: true) int progress,
      @JsonKey(name: 'location') String? location,
      @JsonKey(name: 'owner_id') String? ownerId,
      @JsonKey(name: 'projects', required: true) List<ProjectInfo> projects,
      @JsonKey(name: 'tags', required: true) List<TagInfo> tags,
      @JsonKey(name: 'reminders', required: true) List<ReminderInfo> reminders,
      @JsonKey(name: 'attachments', required: true)
      List<AttachmentInfo> attachments});
}

/// @nodoc
class _$TodoResponseCopyWithImpl<$Res, $Val extends TodoResponse>
    implements $TodoResponseCopyWith<$Res> {
  _$TodoResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TodoResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? title = null,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? dueAt = null,
    Object? priority = null,
    Object? status = null,
    Object? repeat = freezed,
    Object? completedAt = freezed,
    Object? assigneeId = freezed,
    Object? progress = null,
    Object? location = freezed,
    Object? ownerId = freezed,
    Object? projects = null,
    Object? tags = null,
    Object? reminders = null,
    Object? attachments = null,
  }) {
    return _then(_value.copyWith(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      dueAt: null == dueAt
          ? _value.dueAt
          : dueAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as Priority,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as Status,
      repeat: freezed == repeat
          ? _value.repeat
          : repeat // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      assigneeId: freezed == assigneeId
          ? _value.assigneeId
          : assigneeId // ignore: cast_nullable_to_non_nullable
              as String?,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
      projects: null == projects
          ? _value.projects
          : projects // ignore: cast_nullable_to_non_nullable
              as List<ProjectInfo>,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<TagInfo>,
      reminders: null == reminders
          ? _value.reminders
          : reminders // ignore: cast_nullable_to_non_nullable
              as List<ReminderInfo>,
      attachments: null == attachments
          ? _value.attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<AttachmentInfo>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TodoResponseImplCopyWith<$Res>
    implements $TodoResponseCopyWith<$Res> {
  factory _$$TodoResponseImplCopyWith(
          _$TodoResponseImpl value, $Res Function(_$TodoResponseImpl) then) =
      __$$TodoResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'serial_num', required: true) String serialNum,
      @JsonKey(name: 'title', required: true) String title,
      @JsonKey(name: 'description') String? description,
      @JsonKey(
          name: 'created_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      DateTime? updatedAt,
      @JsonKey(
          name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      DateTime dueAt,
      @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
      Priority priority,
      @JsonKey(fromJson: Status.fromJson, toJson: statusToJson) Status status,
      @JsonKey(name: 'repeat') String? repeat,
      @JsonKey(
          name: 'completed_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      DateTime? completedAt,
      @JsonKey(name: 'assignee_id') String? assigneeId,
      @JsonKey(name: 'progress', required: true) int progress,
      @JsonKey(name: 'location') String? location,
      @JsonKey(name: 'owner_id') String? ownerId,
      @JsonKey(name: 'projects', required: true) List<ProjectInfo> projects,
      @JsonKey(name: 'tags', required: true) List<TagInfo> tags,
      @JsonKey(name: 'reminders', required: true) List<ReminderInfo> reminders,
      @JsonKey(name: 'attachments', required: true)
      List<AttachmentInfo> attachments});
}

/// @nodoc
class __$$TodoResponseImplCopyWithImpl<$Res>
    extends _$TodoResponseCopyWithImpl<$Res, _$TodoResponseImpl>
    implements _$$TodoResponseImplCopyWith<$Res> {
  __$$TodoResponseImplCopyWithImpl(
      _$TodoResponseImpl _value, $Res Function(_$TodoResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of TodoResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serialNum = null,
    Object? title = null,
    Object? description = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? dueAt = null,
    Object? priority = null,
    Object? status = null,
    Object? repeat = freezed,
    Object? completedAt = freezed,
    Object? assigneeId = freezed,
    Object? progress = null,
    Object? location = freezed,
    Object? ownerId = freezed,
    Object? projects = null,
    Object? tags = null,
    Object? reminders = null,
    Object? attachments = null,
  }) {
    return _then(_$TodoResponseImpl(
      serialNum: null == serialNum
          ? _value.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      dueAt: null == dueAt
          ? _value.dueAt
          : dueAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as Priority,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as Status,
      repeat: freezed == repeat
          ? _value.repeat
          : repeat // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      assigneeId: freezed == assigneeId
          ? _value.assigneeId
          : assigneeId // ignore: cast_nullable_to_non_nullable
              as String?,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
      projects: null == projects
          ? _value._projects
          : projects // ignore: cast_nullable_to_non_nullable
              as List<ProjectInfo>,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<TagInfo>,
      reminders: null == reminders
          ? _value._reminders
          : reminders // ignore: cast_nullable_to_non_nullable
              as List<ReminderInfo>,
      attachments: null == attachments
          ? _value._attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<AttachmentInfo>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TodoResponseImpl implements _TodoResponse {
  const _$TodoResponseImpl(
      {@JsonKey(name: 'serial_num', required: true) required this.serialNum,
      @JsonKey(name: 'title', required: true) required this.title,
      @JsonKey(name: 'description') this.description,
      @JsonKey(
          name: 'created_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      required this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      this.updatedAt,
      @JsonKey(
          name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      required this.dueAt,
      @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
      required this.priority,
      @JsonKey(fromJson: Status.fromJson, toJson: statusToJson)
      required this.status,
      @JsonKey(name: 'repeat') this.repeat,
      @JsonKey(
          name: 'completed_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      this.completedAt,
      @JsonKey(name: 'assignee_id') this.assigneeId,
      @JsonKey(name: 'progress', required: true) required this.progress,
      @JsonKey(name: 'location') this.location,
      @JsonKey(name: 'owner_id') this.ownerId,
      @JsonKey(name: 'projects', required: true)
      required final List<ProjectInfo> projects,
      @JsonKey(name: 'tags', required: true) required final List<TagInfo> tags,
      @JsonKey(name: 'reminders', required: true)
      required final List<ReminderInfo> reminders,
      @JsonKey(name: 'attachments', required: true)
      required final List<AttachmentInfo> attachments})
      : _projects = projects,
        _tags = tags,
        _reminders = reminders,
        _attachments = attachments;

  factory _$TodoResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$TodoResponseImplFromJson(json);

  @override
  @JsonKey(name: 'serial_num', required: true)
  final String serialNum;
  @override
  @JsonKey(name: 'title', required: true)
  final String title;
  @override
  @JsonKey(name: 'description')
  final String? description;
  @override
  @JsonKey(
      name: 'created_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime? updatedAt;
  @override
  @JsonKey(name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime dueAt;
  @override
  @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
  final Priority priority;
  @override
  @JsonKey(fromJson: Status.fromJson, toJson: statusToJson)
  final Status status;
  @override
  @JsonKey(name: 'repeat')
  final String? repeat;
  @override
  @JsonKey(
      name: 'completed_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  final DateTime? completedAt;
  @override
  @JsonKey(name: 'assignee_id')
  final String? assigneeId;
  @override
  @JsonKey(name: 'progress', required: true)
  final int progress;
  @override
  @JsonKey(name: 'location')
  final String? location;
  @override
  @JsonKey(name: 'owner_id')
  final String? ownerId;
  final List<ProjectInfo> _projects;
  @override
  @JsonKey(name: 'projects', required: true)
  List<ProjectInfo> get projects {
    if (_projects is EqualUnmodifiableListView) return _projects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_projects);
  }

  final List<TagInfo> _tags;
  @override
  @JsonKey(name: 'tags', required: true)
  List<TagInfo> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  final List<ReminderInfo> _reminders;
  @override
  @JsonKey(name: 'reminders', required: true)
  List<ReminderInfo> get reminders {
    if (_reminders is EqualUnmodifiableListView) return _reminders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reminders);
  }

  final List<AttachmentInfo> _attachments;
  @override
  @JsonKey(name: 'attachments', required: true)
  List<AttachmentInfo> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

  @override
  String toString() {
    return 'TodoResponse(serialNum: $serialNum, title: $title, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, dueAt: $dueAt, priority: $priority, status: $status, repeat: $repeat, completedAt: $completedAt, assigneeId: $assigneeId, progress: $progress, location: $location, ownerId: $ownerId, projects: $projects, tags: $tags, reminders: $reminders, attachments: $attachments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TodoResponseImpl &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.dueAt, dueAt) || other.dueAt == dueAt) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.repeat, repeat) || other.repeat == repeat) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.assigneeId, assigneeId) ||
                other.assigneeId == assigneeId) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            const DeepCollectionEquality().equals(other._projects, _projects) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality()
                .equals(other._reminders, _reminders) &&
            const DeepCollectionEquality()
                .equals(other._attachments, _attachments));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      serialNum,
      title,
      description,
      createdAt,
      updatedAt,
      dueAt,
      priority,
      status,
      repeat,
      completedAt,
      assigneeId,
      progress,
      location,
      ownerId,
      const DeepCollectionEquality().hash(_projects),
      const DeepCollectionEquality().hash(_tags),
      const DeepCollectionEquality().hash(_reminders),
      const DeepCollectionEquality().hash(_attachments));

  /// Create a copy of TodoResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TodoResponseImplCopyWith<_$TodoResponseImpl> get copyWith =>
      __$$TodoResponseImplCopyWithImpl<_$TodoResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TodoResponseImplToJson(
      this,
    );
  }
}

abstract class _TodoResponse implements TodoResponse {
  const factory _TodoResponse(
      {@JsonKey(name: 'serial_num', required: true)
      required final String serialNum,
      @JsonKey(name: 'title', required: true) required final String title,
      @JsonKey(name: 'description') final String? description,
      @JsonKey(
          name: 'created_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      required final DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      final DateTime? updatedAt,
      @JsonKey(
          name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
      required final DateTime dueAt,
      @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
      required final Priority priority,
      @JsonKey(fromJson: Status.fromJson, toJson: statusToJson)
      required final Status status,
      @JsonKey(name: 'repeat') final String? repeat,
      @JsonKey(
          name: 'completed_at',
          fromJson: dateTimeFromJson,
          toJson: dateTimeToJson)
      final DateTime? completedAt,
      @JsonKey(name: 'assignee_id') final String? assigneeId,
      @JsonKey(name: 'progress', required: true) required final int progress,
      @JsonKey(name: 'location') final String? location,
      @JsonKey(name: 'owner_id') final String? ownerId,
      @JsonKey(name: 'projects', required: true)
      required final List<ProjectInfo> projects,
      @JsonKey(name: 'tags', required: true) required final List<TagInfo> tags,
      @JsonKey(name: 'reminders', required: true)
      required final List<ReminderInfo> reminders,
      @JsonKey(name: 'attachments', required: true)
      required final List<AttachmentInfo> attachments}) = _$TodoResponseImpl;

  factory _TodoResponse.fromJson(Map<String, dynamic> json) =
      _$TodoResponseImpl.fromJson;

  @override
  @JsonKey(name: 'serial_num', required: true)
  String get serialNum;
  @override
  @JsonKey(name: 'title', required: true)
  String get title;
  @override
  @JsonKey(name: 'description')
  String? get description;
  @override
  @JsonKey(
      name: 'created_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'updated_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime? get updatedAt;
  @override
  @JsonKey(name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime get dueAt;
  @override
  @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
  Priority get priority;
  @override
  @JsonKey(fromJson: Status.fromJson, toJson: statusToJson)
  Status get status;
  @override
  @JsonKey(name: 'repeat')
  String? get repeat;
  @override
  @JsonKey(
      name: 'completed_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
  DateTime? get completedAt;
  @override
  @JsonKey(name: 'assignee_id')
  String? get assigneeId;
  @override
  @JsonKey(name: 'progress', required: true)
  int get progress;
  @override
  @JsonKey(name: 'location')
  String? get location;
  @override
  @JsonKey(name: 'owner_id')
  String? get ownerId;
  @override
  @JsonKey(name: 'projects', required: true)
  List<ProjectInfo> get projects;
  @override
  @JsonKey(name: 'tags', required: true)
  List<TagInfo> get tags;
  @override
  @JsonKey(name: 'reminders', required: true)
  List<ReminderInfo> get reminders;
  @override
  @JsonKey(name: 'attachments', required: true)
  List<AttachmentInfo> get attachments;

  /// Create a copy of TodoResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TodoResponseImplCopyWith<_$TodoResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
