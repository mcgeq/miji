// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Todos {
  @JsonKey(name: 'assignee_id')
  String? get assigneeId;
  @JsonKey(name: 'attachments')
  List<dynamic> get attachments;
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'description')
  String? get description;
  @JsonKey(name: 'due_at')
  DateTime get dueAt;
  @JsonKey(name: 'location')
  String? get location;
  @JsonKey(name: 'owner_id')
  String? get ownerId;
  @JsonKey(name: 'priority')
  int get priority;
  @JsonKey(name: 'progress')
  int get progress;
  @JsonKey(name: 'projects')
  List<Projects> get projects;
  @JsonKey(name: 'reminders')
  List<dynamic> get reminders;
  @JsonKey(name: 'repeat')
  String? get repeat;
  @JsonKey(name: 'serial_num')
  String get serialNum;
  @JsonKey(name: 'status')
  int get status;
  @JsonKey(name: 'tags')
  List<dynamic> get tags;
  @JsonKey(name: 'title')
  String get title;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of Todos
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TodosCopyWith<Todos> get copyWith =>
      _$TodosCopyWithImpl<Todos>(this as Todos, _$identity);

  /// Serializes this Todos to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Todos &&
            (identical(other.assigneeId, assigneeId) ||
                other.assigneeId == assigneeId) &&
            const DeepCollectionEquality()
                .equals(other.attachments, attachments) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.dueAt, dueAt) || other.dueAt == dueAt) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            const DeepCollectionEquality().equals(other.projects, projects) &&
            const DeepCollectionEquality().equals(other.reminders, reminders) &&
            (identical(other.repeat, repeat) || other.repeat == repeat) &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.tags, tags) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      assigneeId,
      const DeepCollectionEquality().hash(attachments),
      completedAt,
      createdAt,
      description,
      dueAt,
      location,
      ownerId,
      priority,
      progress,
      const DeepCollectionEquality().hash(projects),
      const DeepCollectionEquality().hash(reminders),
      repeat,
      serialNum,
      status,
      const DeepCollectionEquality().hash(tags),
      title,
      updatedAt);

  @override
  String toString() {
    return 'Todos(assigneeId: $assigneeId, attachments: $attachments, completedAt: $completedAt, createdAt: $createdAt, description: $description, dueAt: $dueAt, location: $location, ownerId: $ownerId, priority: $priority, progress: $progress, projects: $projects, reminders: $reminders, repeat: $repeat, serialNum: $serialNum, status: $status, tags: $tags, title: $title, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $TodosCopyWith<$Res> {
  factory $TodosCopyWith(Todos value, $Res Function(Todos) _then) =
      _$TodosCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'assignee_id') String? assigneeId,
      @JsonKey(name: 'attachments') List<dynamic> attachments,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'description') String? description,
      @JsonKey(name: 'due_at') DateTime dueAt,
      @JsonKey(name: 'location') String? location,
      @JsonKey(name: 'owner_id') String? ownerId,
      @JsonKey(name: 'priority') int priority,
      @JsonKey(name: 'progress') int progress,
      @JsonKey(name: 'projects') List<Projects> projects,
      @JsonKey(name: 'reminders') List<dynamic> reminders,
      @JsonKey(name: 'repeat') String? repeat,
      @JsonKey(name: 'serial_num') String serialNum,
      @JsonKey(name: 'status') int status,
      @JsonKey(name: 'tags') List<dynamic> tags,
      @JsonKey(name: 'title') String title,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$TodosCopyWithImpl<$Res> implements $TodosCopyWith<$Res> {
  _$TodosCopyWithImpl(this._self, this._then);

  final Todos _self;
  final $Res Function(Todos) _then;

  /// Create a copy of Todos
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? assigneeId = freezed,
    Object? attachments = null,
    Object? completedAt = freezed,
    Object? createdAt = null,
    Object? description = freezed,
    Object? dueAt = null,
    Object? location = freezed,
    Object? ownerId = freezed,
    Object? priority = null,
    Object? progress = null,
    Object? projects = null,
    Object? reminders = null,
    Object? repeat = freezed,
    Object? serialNum = null,
    Object? status = null,
    Object? tags = null,
    Object? title = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_self.copyWith(
      assigneeId: freezed == assigneeId
          ? _self.assigneeId
          : assigneeId // ignore: cast_nullable_to_non_nullable
              as String?,
      attachments: null == attachments
          ? _self.attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      dueAt: null == dueAt
          ? _self.dueAt
          : dueAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _self.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _self.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      projects: null == projects
          ? _self.projects
          : projects // ignore: cast_nullable_to_non_nullable
              as List<Projects>,
      reminders: null == reminders
          ? _self.reminders
          : reminders // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      repeat: freezed == repeat
          ? _self.repeat
          : repeat // ignore: cast_nullable_to_non_nullable
              as String?,
      serialNum: null == serialNum
          ? _self.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      tags: null == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Todos implements Todos {
  const _Todos(
      {@JsonKey(name: 'assignee_id') this.assigneeId,
      @JsonKey(name: 'attachments') final List<dynamic> attachments = const [],
      @JsonKey(name: 'completed_at') this.completedAt,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'description') this.description,
      @JsonKey(name: 'due_at') required this.dueAt,
      @JsonKey(name: 'location') this.location,
      @JsonKey(name: 'owner_id') this.ownerId,
      @JsonKey(name: 'priority') this.priority = 0,
      @JsonKey(name: 'progress') this.progress = 0,
      @JsonKey(name: 'projects') final List<Projects> projects = const [],
      @JsonKey(name: 'reminders') final List<dynamic> reminders = const [],
      @JsonKey(name: 'repeat') this.repeat,
      @JsonKey(name: 'serial_num') required this.serialNum,
      @JsonKey(name: 'status') required this.status,
      @JsonKey(name: 'tags') final List<dynamic> tags = const [],
      @JsonKey(name: 'title') required this.title,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : _attachments = attachments,
        _projects = projects,
        _reminders = reminders,
        _tags = tags;
  factory _Todos.fromJson(Map<String, dynamic> json) => _$TodosFromJson(json);

  @override
  @JsonKey(name: 'assignee_id')
  final String? assigneeId;
  final List<dynamic> _attachments;
  @override
  @JsonKey(name: 'attachments')
  List<dynamic> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

  @override
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'description')
  final String? description;
  @override
  @JsonKey(name: 'due_at')
  final DateTime dueAt;
  @override
  @JsonKey(name: 'location')
  final String? location;
  @override
  @JsonKey(name: 'owner_id')
  final String? ownerId;
  @override
  @JsonKey(name: 'priority')
  final int priority;
  @override
  @JsonKey(name: 'progress')
  final int progress;
  final List<Projects> _projects;
  @override
  @JsonKey(name: 'projects')
  List<Projects> get projects {
    if (_projects is EqualUnmodifiableListView) return _projects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_projects);
  }

  final List<dynamic> _reminders;
  @override
  @JsonKey(name: 'reminders')
  List<dynamic> get reminders {
    if (_reminders is EqualUnmodifiableListView) return _reminders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reminders);
  }

  @override
  @JsonKey(name: 'repeat')
  final String? repeat;
  @override
  @JsonKey(name: 'serial_num')
  final String serialNum;
  @override
  @JsonKey(name: 'status')
  final int status;
  final List<dynamic> _tags;
  @override
  @JsonKey(name: 'tags')
  List<dynamic> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey(name: 'title')
  final String title;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Create a copy of Todos
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TodosCopyWith<_Todos> get copyWith =>
      __$TodosCopyWithImpl<_Todos>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TodosToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Todos &&
            (identical(other.assigneeId, assigneeId) ||
                other.assigneeId == assigneeId) &&
            const DeepCollectionEquality()
                .equals(other._attachments, _attachments) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.dueAt, dueAt) || other.dueAt == dueAt) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            const DeepCollectionEquality().equals(other._projects, _projects) &&
            const DeepCollectionEquality()
                .equals(other._reminders, _reminders) &&
            (identical(other.repeat, repeat) || other.repeat == repeat) &&
            (identical(other.serialNum, serialNum) ||
                other.serialNum == serialNum) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      assigneeId,
      const DeepCollectionEquality().hash(_attachments),
      completedAt,
      createdAt,
      description,
      dueAt,
      location,
      ownerId,
      priority,
      progress,
      const DeepCollectionEquality().hash(_projects),
      const DeepCollectionEquality().hash(_reminders),
      repeat,
      serialNum,
      status,
      const DeepCollectionEquality().hash(_tags),
      title,
      updatedAt);

  @override
  String toString() {
    return 'Todos(assigneeId: $assigneeId, attachments: $attachments, completedAt: $completedAt, createdAt: $createdAt, description: $description, dueAt: $dueAt, location: $location, ownerId: $ownerId, priority: $priority, progress: $progress, projects: $projects, reminders: $reminders, repeat: $repeat, serialNum: $serialNum, status: $status, tags: $tags, title: $title, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$TodosCopyWith<$Res> implements $TodosCopyWith<$Res> {
  factory _$TodosCopyWith(_Todos value, $Res Function(_Todos) _then) =
      __$TodosCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'assignee_id') String? assigneeId,
      @JsonKey(name: 'attachments') List<dynamic> attachments,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'description') String? description,
      @JsonKey(name: 'due_at') DateTime dueAt,
      @JsonKey(name: 'location') String? location,
      @JsonKey(name: 'owner_id') String? ownerId,
      @JsonKey(name: 'priority') int priority,
      @JsonKey(name: 'progress') int progress,
      @JsonKey(name: 'projects') List<Projects> projects,
      @JsonKey(name: 'reminders') List<dynamic> reminders,
      @JsonKey(name: 'repeat') String? repeat,
      @JsonKey(name: 'serial_num') String serialNum,
      @JsonKey(name: 'status') int status,
      @JsonKey(name: 'tags') List<dynamic> tags,
      @JsonKey(name: 'title') String title,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$TodosCopyWithImpl<$Res> implements _$TodosCopyWith<$Res> {
  __$TodosCopyWithImpl(this._self, this._then);

  final _Todos _self;
  final $Res Function(_Todos) _then;

  /// Create a copy of Todos
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? assigneeId = freezed,
    Object? attachments = null,
    Object? completedAt = freezed,
    Object? createdAt = null,
    Object? description = freezed,
    Object? dueAt = null,
    Object? location = freezed,
    Object? ownerId = freezed,
    Object? priority = null,
    Object? progress = null,
    Object? projects = null,
    Object? reminders = null,
    Object? repeat = freezed,
    Object? serialNum = null,
    Object? status = null,
    Object? tags = null,
    Object? title = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_Todos(
      assigneeId: freezed == assigneeId
          ? _self.assigneeId
          : assigneeId // ignore: cast_nullable_to_non_nullable
              as String?,
      attachments: null == attachments
          ? _self._attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      dueAt: null == dueAt
          ? _self.dueAt
          : dueAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: freezed == ownerId
          ? _self.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _self.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      projects: null == projects
          ? _self._projects
          : projects // ignore: cast_nullable_to_non_nullable
              as List<Projects>,
      reminders: null == reminders
          ? _self._reminders
          : reminders // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      repeat: freezed == repeat
          ? _self.repeat
          : repeat // ignore: cast_nullable_to_non_nullable
              as String?,
      serialNum: null == serialNum
          ? _self.serialNum
          : serialNum // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      tags: null == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
