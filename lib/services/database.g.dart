// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, parentId, name, createdAt, isDeleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<Project> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String? parentId;
  final String name;
  final DateTime createdAt;
  final bool isDeleted;
  const Project(
      {required this.id,
      this.parentId,
      required this.name,
      required this.createdAt,
      required this.isDeleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      createdAt: Value(createdAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory Project.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Project copyWith(
          {String? id,
          Value<String?> parentId = const Value.absent(),
          String? name,
          DateTime? createdAt,
          bool? isDeleted}) =>
      Project(
        id: id ?? this.id,
        parentId: parentId.present ? parentId.value : this.parentId,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, name, createdAt, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.isDeleted == this.isDeleted);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? parentId,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<bool>? isDeleted,
      Value<int>? rowid}) {
    return ProjectsCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DrawingsTable extends Drawings with TableInfo<$DrawingsTable, Drawing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DrawingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localFilePathMeta =
      const VerificationMeta('localFilePath');
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<String> units = GeneratedColumn<String>(
      'units', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('m'));
  static const VerificationMeta _nextAnnotationNumberMeta =
      const VerificationMeta('nextAnnotationNumber');
  @override
  late final GeneratedColumn<int> nextAnnotationNumber = GeneratedColumn<int>(
      'next_annotation_number', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _contentHashMeta =
      const VerificationMeta('contentHash');
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
      'content_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        name,
        localFilePath,
        units,
        nextAnnotationNumber,
        contentHash,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drawings';
  @override
  VerificationContext validateIntegrity(Insertable<Drawing> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
          _localFilePathMeta,
          localFilePath.isAcceptableOrUnknown(
              data['local_file_path']!, _localFilePathMeta));
    } else if (isInserting) {
      context.missing(_localFilePathMeta);
    }
    if (data.containsKey('units')) {
      context.handle(
          _unitsMeta, units.isAcceptableOrUnknown(data['units']!, _unitsMeta));
    }
    if (data.containsKey('next_annotation_number')) {
      context.handle(
          _nextAnnotationNumberMeta,
          nextAnnotationNumber.isAcceptableOrUnknown(
              data['next_annotation_number']!, _nextAnnotationNumberMeta));
    }
    if (data.containsKey('content_hash')) {
      context.handle(
          _contentHashMeta,
          contentHash.isAcceptableOrUnknown(
              data['content_hash']!, _contentHashMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Drawing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Drawing(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      localFilePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_file_path'])!,
      units: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}units'])!,
      nextAnnotationNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}next_annotation_number'])!,
      contentHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_hash']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DrawingsTable createAlias(String alias) {
    return $DrawingsTable(attachedDatabase, alias);
  }
}

class Drawing extends DataClass implements Insertable<Drawing> {
  final String id;
  final String projectId;
  final String name;
  final String localFilePath;
  final String units;
  final int nextAnnotationNumber;
  final String? contentHash;
  final DateTime createdAt;
  const Drawing(
      {required this.id,
      required this.projectId,
      required this.name,
      required this.localFilePath,
      required this.units,
      required this.nextAnnotationNumber,
      this.contentHash,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['local_file_path'] = Variable<String>(localFilePath);
    map['units'] = Variable<String>(units);
    map['next_annotation_number'] = Variable<int>(nextAnnotationNumber);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DrawingsCompanion toCompanion(bool nullToAbsent) {
    return DrawingsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      localFilePath: Value(localFilePath),
      units: Value(units),
      nextAnnotationNumber: Value(nextAnnotationNumber),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      createdAt: Value(createdAt),
    );
  }

  factory Drawing.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Drawing(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      localFilePath: serializer.fromJson<String>(json['localFilePath']),
      units: serializer.fromJson<String>(json['units']),
      nextAnnotationNumber:
          serializer.fromJson<int>(json['nextAnnotationNumber']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'localFilePath': serializer.toJson<String>(localFilePath),
      'units': serializer.toJson<String>(units),
      'nextAnnotationNumber': serializer.toJson<int>(nextAnnotationNumber),
      'contentHash': serializer.toJson<String?>(contentHash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Drawing copyWith(
          {String? id,
          String? projectId,
          String? name,
          String? localFilePath,
          String? units,
          int? nextAnnotationNumber,
          Value<String?> contentHash = const Value.absent(),
          DateTime? createdAt}) =>
      Drawing(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        localFilePath: localFilePath ?? this.localFilePath,
        units: units ?? this.units,
        nextAnnotationNumber: nextAnnotationNumber ?? this.nextAnnotationNumber,
        contentHash: contentHash.present ? contentHash.value : this.contentHash,
        createdAt: createdAt ?? this.createdAt,
      );
  Drawing copyWithCompanion(DrawingsCompanion data) {
    return Drawing(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      units: data.units.present ? data.units.value : this.units,
      nextAnnotationNumber: data.nextAnnotationNumber.present
          ? data.nextAnnotationNumber.value
          : this.nextAnnotationNumber,
      contentHash:
          data.contentHash.present ? data.contentHash.value : this.contentHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Drawing(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('units: $units, ')
          ..write('nextAnnotationNumber: $nextAnnotationNumber, ')
          ..write('contentHash: $contentHash, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, name, localFilePath, units,
      nextAnnotationNumber, contentHash, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Drawing &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.localFilePath == this.localFilePath &&
          other.units == this.units &&
          other.nextAnnotationNumber == this.nextAnnotationNumber &&
          other.contentHash == this.contentHash &&
          other.createdAt == this.createdAt);
}

class DrawingsCompanion extends UpdateCompanion<Drawing> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<String> localFilePath;
  final Value<String> units;
  final Value<int> nextAnnotationNumber;
  final Value<String?> contentHash;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DrawingsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.units = const Value.absent(),
    this.nextAnnotationNumber = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DrawingsCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    required String localFilePath,
    this.units = const Value.absent(),
    this.nextAnnotationNumber = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        name = Value(name),
        localFilePath = Value(localFilePath);
  static Insertable<Drawing> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? localFilePath,
    Expression<String>? units,
    Expression<int>? nextAnnotationNumber,
    Expression<String>? contentHash,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (units != null) 'units': units,
      if (nextAnnotationNumber != null)
        'next_annotation_number': nextAnnotationNumber,
      if (contentHash != null) 'content_hash': contentHash,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DrawingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? name,
      Value<String>? localFilePath,
      Value<String>? units,
      Value<int>? nextAnnotationNumber,
      Value<String?>? contentHash,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return DrawingsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      localFilePath: localFilePath ?? this.localFilePath,
      units: units ?? this.units,
      nextAnnotationNumber: nextAnnotationNumber ?? this.nextAnnotationNumber,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (units.present) {
      map['units'] = Variable<String>(units.value);
    }
    if (nextAnnotationNumber.present) {
      map['next_annotation_number'] = Variable<int>(nextAnnotationNumber.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DrawingsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('units: $units, ')
          ..write('nextAnnotationNumber: $nextAnnotationNumber, ')
          ..write('contentHash: $contentHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationRowsTable extends AnnotationRows
    with TableInfo<$AnnotationRowsTable, AnnotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _drawingIdMeta =
      const VerificationMeta('drawingId');
  @override
  late final GeneratedColumn<String> drawingId = GeneratedColumn<String>(
      'drawing_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
      'number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dxfXMeta = const VerificationMeta('dxfX');
  @override
  late final GeneratedColumn<double> dxfX = GeneratedColumn<double>(
      'dxf_x', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _dxfYMeta = const VerificationMeta('dxfY');
  @override
  late final GeneratedColumn<double> dxfY = GeneratedColumn<double>(
      'dxf_y', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _geoXMeta = const VerificationMeta('geoX');
  @override
  late final GeneratedColumn<double> geoX = GeneratedColumn<double>(
      'geo_x', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _geoYMeta = const VerificationMeta('geoY');
  @override
  late final GeneratedColumn<double> geoY = GeneratedColumn<double>(
      'geo_y', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _geoZMeta = const VerificationMeta('geoZ');
  @override
  late final GeneratedColumn<double> geoZ = GeneratedColumn<double>(
      'geo_z', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        drawingId,
        number,
        dxfX,
        dxfY,
        geoX,
        geoY,
        geoZ,
        code,
        description,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotation_rows';
  @override
  VerificationContext validateIntegrity(Insertable<AnnotationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('drawing_id')) {
      context.handle(_drawingIdMeta,
          drawingId.isAcceptableOrUnknown(data['drawing_id']!, _drawingIdMeta));
    } else if (isInserting) {
      context.missing(_drawingIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('dxf_x')) {
      context.handle(
          _dxfXMeta, dxfX.isAcceptableOrUnknown(data['dxf_x']!, _dxfXMeta));
    } else if (isInserting) {
      context.missing(_dxfXMeta);
    }
    if (data.containsKey('dxf_y')) {
      context.handle(
          _dxfYMeta, dxfY.isAcceptableOrUnknown(data['dxf_y']!, _dxfYMeta));
    } else if (isInserting) {
      context.missing(_dxfYMeta);
    }
    if (data.containsKey('geo_x')) {
      context.handle(
          _geoXMeta, geoX.isAcceptableOrUnknown(data['geo_x']!, _geoXMeta));
    }
    if (data.containsKey('geo_y')) {
      context.handle(
          _geoYMeta, geoY.isAcceptableOrUnknown(data['geo_y']!, _geoYMeta));
    }
    if (data.containsKey('geo_z')) {
      context.handle(
          _geoZMeta, geoZ.isAcceptableOrUnknown(data['geo_z']!, _geoZMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnotationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnotationRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      drawingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drawing_id'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}number'])!,
      dxfX: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}dxf_x'])!,
      dxfY: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}dxf_y'])!,
      geoX: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}geo_x']),
      geoY: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}geo_y']),
      geoZ: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}geo_z']),
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $AnnotationRowsTable createAlias(String alias) {
    return $AnnotationRowsTable(attachedDatabase, alias);
  }
}

class AnnotationRow extends DataClass implements Insertable<AnnotationRow> {
  final String id;
  final String drawingId;
  final int number;
  final double dxfX;
  final double dxfY;
  final double? geoX;
  final double? geoY;
  final double? geoZ;
  final String? code;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  const AnnotationRow(
      {required this.id,
      required this.drawingId,
      required this.number,
      required this.dxfX,
      required this.dxfY,
      this.geoX,
      this.geoY,
      this.geoZ,
      this.code,
      this.description,
      required this.createdAt,
      this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['drawing_id'] = Variable<String>(drawingId);
    map['number'] = Variable<int>(number);
    map['dxf_x'] = Variable<double>(dxfX);
    map['dxf_y'] = Variable<double>(dxfY);
    if (!nullToAbsent || geoX != null) {
      map['geo_x'] = Variable<double>(geoX);
    }
    if (!nullToAbsent || geoY != null) {
      map['geo_y'] = Variable<double>(geoY);
    }
    if (!nullToAbsent || geoZ != null) {
      map['geo_z'] = Variable<double>(geoZ);
    }
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AnnotationRowsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationRowsCompanion(
      id: Value(id),
      drawingId: Value(drawingId),
      number: Value(number),
      dxfX: Value(dxfX),
      dxfY: Value(dxfY),
      geoX: geoX == null && nullToAbsent ? const Value.absent() : Value(geoX),
      geoY: geoY == null && nullToAbsent ? const Value.absent() : Value(geoY),
      geoZ: geoZ == null && nullToAbsent ? const Value.absent() : Value(geoZ),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AnnotationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnotationRow(
      id: serializer.fromJson<String>(json['id']),
      drawingId: serializer.fromJson<String>(json['drawingId']),
      number: serializer.fromJson<int>(json['number']),
      dxfX: serializer.fromJson<double>(json['dxfX']),
      dxfY: serializer.fromJson<double>(json['dxfY']),
      geoX: serializer.fromJson<double?>(json['geoX']),
      geoY: serializer.fromJson<double?>(json['geoY']),
      geoZ: serializer.fromJson<double?>(json['geoZ']),
      code: serializer.fromJson<String?>(json['code']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'drawingId': serializer.toJson<String>(drawingId),
      'number': serializer.toJson<int>(number),
      'dxfX': serializer.toJson<double>(dxfX),
      'dxfY': serializer.toJson<double>(dxfY),
      'geoX': serializer.toJson<double?>(geoX),
      'geoY': serializer.toJson<double?>(geoY),
      'geoZ': serializer.toJson<double?>(geoZ),
      'code': serializer.toJson<String?>(code),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AnnotationRow copyWith(
          {String? id,
          String? drawingId,
          int? number,
          double? dxfX,
          double? dxfY,
          Value<double?> geoX = const Value.absent(),
          Value<double?> geoY = const Value.absent(),
          Value<double?> geoZ = const Value.absent(),
          Value<String?> code = const Value.absent(),
          Value<String?> description = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      AnnotationRow(
        id: id ?? this.id,
        drawingId: drawingId ?? this.drawingId,
        number: number ?? this.number,
        dxfX: dxfX ?? this.dxfX,
        dxfY: dxfY ?? this.dxfY,
        geoX: geoX.present ? geoX.value : this.geoX,
        geoY: geoY.present ? geoY.value : this.geoY,
        geoZ: geoZ.present ? geoZ.value : this.geoZ,
        code: code.present ? code.value : this.code,
        description: description.present ? description.value : this.description,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  AnnotationRow copyWithCompanion(AnnotationRowsCompanion data) {
    return AnnotationRow(
      id: data.id.present ? data.id.value : this.id,
      drawingId: data.drawingId.present ? data.drawingId.value : this.drawingId,
      number: data.number.present ? data.number.value : this.number,
      dxfX: data.dxfX.present ? data.dxfX.value : this.dxfX,
      dxfY: data.dxfY.present ? data.dxfY.value : this.dxfY,
      geoX: data.geoX.present ? data.geoX.value : this.geoX,
      geoY: data.geoY.present ? data.geoY.value : this.geoY,
      geoZ: data.geoZ.present ? data.geoZ.value : this.geoZ,
      code: data.code.present ? data.code.value : this.code,
      description:
          data.description.present ? data.description.value : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationRow(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('number: $number, ')
          ..write('dxfX: $dxfX, ')
          ..write('dxfY: $dxfY, ')
          ..write('geoX: $geoX, ')
          ..write('geoY: $geoY, ')
          ..write('geoZ: $geoZ, ')
          ..write('code: $code, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, drawingId, number, dxfX, dxfY, geoX, geoY,
      geoZ, code, description, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnotationRow &&
          other.id == this.id &&
          other.drawingId == this.drawingId &&
          other.number == this.number &&
          other.dxfX == this.dxfX &&
          other.dxfY == this.dxfY &&
          other.geoX == this.geoX &&
          other.geoY == this.geoY &&
          other.geoZ == this.geoZ &&
          other.code == this.code &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AnnotationRowsCompanion extends UpdateCompanion<AnnotationRow> {
  final Value<String> id;
  final Value<String> drawingId;
  final Value<int> number;
  final Value<double> dxfX;
  final Value<double> dxfY;
  final Value<double?> geoX;
  final Value<double?> geoY;
  final Value<double?> geoZ;
  final Value<String?> code;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AnnotationRowsCompanion({
    this.id = const Value.absent(),
    this.drawingId = const Value.absent(),
    this.number = const Value.absent(),
    this.dxfX = const Value.absent(),
    this.dxfY = const Value.absent(),
    this.geoX = const Value.absent(),
    this.geoY = const Value.absent(),
    this.geoZ = const Value.absent(),
    this.code = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnotationRowsCompanion.insert({
    required String id,
    required String drawingId,
    required int number,
    required double dxfX,
    required double dxfY,
    this.geoX = const Value.absent(),
    this.geoY = const Value.absent(),
    this.geoZ = const Value.absent(),
    this.code = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        drawingId = Value(drawingId),
        number = Value(number),
        dxfX = Value(dxfX),
        dxfY = Value(dxfY);
  static Insertable<AnnotationRow> custom({
    Expression<String>? id,
    Expression<String>? drawingId,
    Expression<int>? number,
    Expression<double>? dxfX,
    Expression<double>? dxfY,
    Expression<double>? geoX,
    Expression<double>? geoY,
    Expression<double>? geoZ,
    Expression<String>? code,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (drawingId != null) 'drawing_id': drawingId,
      if (number != null) 'number': number,
      if (dxfX != null) 'dxf_x': dxfX,
      if (dxfY != null) 'dxf_y': dxfY,
      if (geoX != null) 'geo_x': geoX,
      if (geoY != null) 'geo_y': geoY,
      if (geoZ != null) 'geo_z': geoZ,
      if (code != null) 'code': code,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnotationRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? drawingId,
      Value<int>? number,
      Value<double>? dxfX,
      Value<double>? dxfY,
      Value<double?>? geoX,
      Value<double?>? geoY,
      Value<double?>? geoZ,
      Value<String?>? code,
      Value<String?>? description,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return AnnotationRowsCompanion(
      id: id ?? this.id,
      drawingId: drawingId ?? this.drawingId,
      number: number ?? this.number,
      dxfX: dxfX ?? this.dxfX,
      dxfY: dxfY ?? this.dxfY,
      geoX: geoX ?? this.geoX,
      geoY: geoY ?? this.geoY,
      geoZ: geoZ ?? this.geoZ,
      code: code ?? this.code,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (drawingId.present) {
      map['drawing_id'] = Variable<String>(drawingId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (dxfX.present) {
      map['dxf_x'] = Variable<double>(dxfX.value);
    }
    if (dxfY.present) {
      map['dxf_y'] = Variable<double>(dxfY.value);
    }
    if (geoX.present) {
      map['geo_x'] = Variable<double>(geoX.value);
    }
    if (geoY.present) {
      map['geo_y'] = Variable<double>(geoY.value);
    }
    if (geoZ.present) {
      map['geo_z'] = Variable<double>(geoZ.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationRowsCompanion(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('number: $number, ')
          ..write('dxfX: $dxfX, ')
          ..write('dxfY: $dxfY, ')
          ..write('geoX: $geoX, ')
          ..write('geoY: $geoY, ')
          ..write('geoZ: $geoZ, ')
          ..write('code: $code, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoRowsTable extends PhotoRows
    with TableInfo<$PhotoRowsTable, PhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _annotationIdMeta =
      const VerificationMeta('annotationId');
  @override
  late final GeneratedColumn<String> annotationId = GeneratedColumn<String>(
      'annotation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localFilePathMeta =
      const VerificationMeta('localFilePath');
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isUploadedMeta =
      const VerificationMeta('isUploaded');
  @override
  late final GeneratedColumn<bool> isUploaded = GeneratedColumn<bool>(
      'is_uploaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_uploaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _fileUrlMeta =
      const VerificationMeta('fileUrl');
  @override
  late final GeneratedColumn<String> fileUrl = GeneratedColumn<String>(
      'file_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        annotationId,
        localFilePath,
        thumbnailPath,
        createdAt,
        isUploaded,
        fileUrl
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_rows';
  @override
  VerificationContext validateIntegrity(Insertable<PhotoRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('annotation_id')) {
      context.handle(
          _annotationIdMeta,
          annotationId.isAcceptableOrUnknown(
              data['annotation_id']!, _annotationIdMeta));
    } else if (isInserting) {
      context.missing(_annotationIdMeta);
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
          _localFilePathMeta,
          localFilePath.isAcceptableOrUnknown(
              data['local_file_path']!, _localFilePathMeta));
    } else if (isInserting) {
      context.missing(_localFilePathMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_uploaded')) {
      context.handle(
          _isUploadedMeta,
          isUploaded.isAcceptableOrUnknown(
              data['is_uploaded']!, _isUploadedMeta));
    }
    if (data.containsKey('file_url')) {
      context.handle(_fileUrlMeta,
          fileUrl.isAcceptableOrUnknown(data['file_url']!, _fileUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      annotationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}annotation_id'])!,
      localFilePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_file_path'])!,
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isUploaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_uploaded'])!,
      fileUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_url']),
    );
  }

  @override
  $PhotoRowsTable createAlias(String alias) {
    return $PhotoRowsTable(attachedDatabase, alias);
  }
}

class PhotoRow extends DataClass implements Insertable<PhotoRow> {
  final String id;
  final String annotationId;
  final String localFilePath;
  final String? thumbnailPath;
  final DateTime createdAt;
  final bool isUploaded;
  final String? fileUrl;
  const PhotoRow(
      {required this.id,
      required this.annotationId,
      required this.localFilePath,
      this.thumbnailPath,
      required this.createdAt,
      required this.isUploaded,
      this.fileUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['annotation_id'] = Variable<String>(annotationId);
    map['local_file_path'] = Variable<String>(localFilePath);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_uploaded'] = Variable<bool>(isUploaded);
    if (!nullToAbsent || fileUrl != null) {
      map['file_url'] = Variable<String>(fileUrl);
    }
    return map;
  }

  PhotoRowsCompanion toCompanion(bool nullToAbsent) {
    return PhotoRowsCompanion(
      id: Value(id),
      annotationId: Value(annotationId),
      localFilePath: Value(localFilePath),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      createdAt: Value(createdAt),
      isUploaded: Value(isUploaded),
      fileUrl: fileUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fileUrl),
    );
  }

  factory PhotoRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoRow(
      id: serializer.fromJson<String>(json['id']),
      annotationId: serializer.fromJson<String>(json['annotationId']),
      localFilePath: serializer.fromJson<String>(json['localFilePath']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isUploaded: serializer.fromJson<bool>(json['isUploaded']),
      fileUrl: serializer.fromJson<String?>(json['fileUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'annotationId': serializer.toJson<String>(annotationId),
      'localFilePath': serializer.toJson<String>(localFilePath),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isUploaded': serializer.toJson<bool>(isUploaded),
      'fileUrl': serializer.toJson<String?>(fileUrl),
    };
  }

  PhotoRow copyWith(
          {String? id,
          String? annotationId,
          String? localFilePath,
          Value<String?> thumbnailPath = const Value.absent(),
          DateTime? createdAt,
          bool? isUploaded,
          Value<String?> fileUrl = const Value.absent()}) =>
      PhotoRow(
        id: id ?? this.id,
        annotationId: annotationId ?? this.annotationId,
        localFilePath: localFilePath ?? this.localFilePath,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        createdAt: createdAt ?? this.createdAt,
        isUploaded: isUploaded ?? this.isUploaded,
        fileUrl: fileUrl.present ? fileUrl.value : this.fileUrl,
      );
  PhotoRow copyWithCompanion(PhotoRowsCompanion data) {
    return PhotoRow(
      id: data.id.present ? data.id.value : this.id,
      annotationId: data.annotationId.present
          ? data.annotationId.value
          : this.annotationId,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isUploaded:
          data.isUploaded.present ? data.isUploaded.value : this.isUploaded,
      fileUrl: data.fileUrl.present ? data.fileUrl.value : this.fileUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRow(')
          ..write('id: $id, ')
          ..write('annotationId: $annotationId, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('isUploaded: $isUploaded, ')
          ..write('fileUrl: $fileUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, annotationId, localFilePath,
      thumbnailPath, createdAt, isUploaded, fileUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoRow &&
          other.id == this.id &&
          other.annotationId == this.annotationId &&
          other.localFilePath == this.localFilePath &&
          other.thumbnailPath == this.thumbnailPath &&
          other.createdAt == this.createdAt &&
          other.isUploaded == this.isUploaded &&
          other.fileUrl == this.fileUrl);
}

class PhotoRowsCompanion extends UpdateCompanion<PhotoRow> {
  final Value<String> id;
  final Value<String> annotationId;
  final Value<String> localFilePath;
  final Value<String?> thumbnailPath;
  final Value<DateTime> createdAt;
  final Value<bool> isUploaded;
  final Value<String?> fileUrl;
  final Value<int> rowid;
  const PhotoRowsCompanion({
    this.id = const Value.absent(),
    this.annotationId = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isUploaded = const Value.absent(),
    this.fileUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoRowsCompanion.insert({
    required String id,
    required String annotationId,
    required String localFilePath,
    this.thumbnailPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isUploaded = const Value.absent(),
    this.fileUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        annotationId = Value(annotationId),
        localFilePath = Value(localFilePath);
  static Insertable<PhotoRow> custom({
    Expression<String>? id,
    Expression<String>? annotationId,
    Expression<String>? localFilePath,
    Expression<String>? thumbnailPath,
    Expression<DateTime>? createdAt,
    Expression<bool>? isUploaded,
    Expression<String>? fileUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (annotationId != null) 'annotation_id': annotationId,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (createdAt != null) 'created_at': createdAt,
      if (isUploaded != null) 'is_uploaded': isUploaded,
      if (fileUrl != null) 'file_url': fileUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? annotationId,
      Value<String>? localFilePath,
      Value<String?>? thumbnailPath,
      Value<DateTime>? createdAt,
      Value<bool>? isUploaded,
      Value<String?>? fileUrl,
      Value<int>? rowid}) {
    return PhotoRowsCompanion(
      id: id ?? this.id,
      annotationId: annotationId ?? this.annotationId,
      localFilePath: localFilePath ?? this.localFilePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      isUploaded: isUploaded ?? this.isUploaded,
      fileUrl: fileUrl ?? this.fileUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (annotationId.present) {
      map['annotation_id'] = Variable<String>(annotationId.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isUploaded.present) {
      map['is_uploaded'] = Variable<bool>(isUploaded.value);
    }
    if (fileUrl.present) {
      map['file_url'] = Variable<String>(fileUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRowsCompanion(')
          ..write('id: $id, ')
          ..write('annotationId: $annotationId, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('isUploaded: $isUploaded, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioNoteRowsTable extends AudioNoteRows
    with TableInfo<$AudioNoteRowsTable, AudioNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioNoteRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _annotationIdMeta =
      const VerificationMeta('annotationId');
  @override
  late final GeneratedColumn<String> annotationId = GeneratedColumn<String>(
      'annotation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localFilePathMeta =
      const VerificationMeta('localFilePath');
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, annotationId, localFilePath, durationMs, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_note_rows';
  @override
  VerificationContext validateIntegrity(Insertable<AudioNoteRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('annotation_id')) {
      context.handle(
          _annotationIdMeta,
          annotationId.isAcceptableOrUnknown(
              data['annotation_id']!, _annotationIdMeta));
    } else if (isInserting) {
      context.missing(_annotationIdMeta);
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
          _localFilePathMeta,
          localFilePath.isAcceptableOrUnknown(
              data['local_file_path']!, _localFilePathMeta));
    } else if (isInserting) {
      context.missing(_localFilePathMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioNoteRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      annotationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}annotation_id'])!,
      localFilePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_file_path'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AudioNoteRowsTable createAlias(String alias) {
    return $AudioNoteRowsTable(attachedDatabase, alias);
  }
}

class AudioNoteRow extends DataClass implements Insertable<AudioNoteRow> {
  final String id;
  final String annotationId;
  final String localFilePath;
  final int durationMs;
  final DateTime createdAt;
  const AudioNoteRow(
      {required this.id,
      required this.annotationId,
      required this.localFilePath,
      required this.durationMs,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['annotation_id'] = Variable<String>(annotationId);
    map['local_file_path'] = Variable<String>(localFilePath);
    map['duration_ms'] = Variable<int>(durationMs);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AudioNoteRowsCompanion toCompanion(bool nullToAbsent) {
    return AudioNoteRowsCompanion(
      id: Value(id),
      annotationId: Value(annotationId),
      localFilePath: Value(localFilePath),
      durationMs: Value(durationMs),
      createdAt: Value(createdAt),
    );
  }

  factory AudioNoteRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioNoteRow(
      id: serializer.fromJson<String>(json['id']),
      annotationId: serializer.fromJson<String>(json['annotationId']),
      localFilePath: serializer.fromJson<String>(json['localFilePath']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'annotationId': serializer.toJson<String>(annotationId),
      'localFilePath': serializer.toJson<String>(localFilePath),
      'durationMs': serializer.toJson<int>(durationMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AudioNoteRow copyWith(
          {String? id,
          String? annotationId,
          String? localFilePath,
          int? durationMs,
          DateTime? createdAt}) =>
      AudioNoteRow(
        id: id ?? this.id,
        annotationId: annotationId ?? this.annotationId,
        localFilePath: localFilePath ?? this.localFilePath,
        durationMs: durationMs ?? this.durationMs,
        createdAt: createdAt ?? this.createdAt,
      );
  AudioNoteRow copyWithCompanion(AudioNoteRowsCompanion data) {
    return AudioNoteRow(
      id: data.id.present ? data.id.value : this.id,
      annotationId: data.annotationId.present
          ? data.annotationId.value
          : this.annotationId,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioNoteRow(')
          ..write('id: $id, ')
          ..write('annotationId: $annotationId, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, annotationId, localFilePath, durationMs, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioNoteRow &&
          other.id == this.id &&
          other.annotationId == this.annotationId &&
          other.localFilePath == this.localFilePath &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt);
}

class AudioNoteRowsCompanion extends UpdateCompanion<AudioNoteRow> {
  final Value<String> id;
  final Value<String> annotationId;
  final Value<String> localFilePath;
  final Value<int> durationMs;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AudioNoteRowsCompanion({
    this.id = const Value.absent(),
    this.annotationId = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioNoteRowsCompanion.insert({
    required String id,
    required String annotationId,
    required String localFilePath,
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        annotationId = Value(annotationId),
        localFilePath = Value(localFilePath);
  static Insertable<AudioNoteRow> custom({
    Expression<String>? id,
    Expression<String>? annotationId,
    Expression<String>? localFilePath,
    Expression<int>? durationMs,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (annotationId != null) 'annotation_id': annotationId,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioNoteRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? annotationId,
      Value<String>? localFilePath,
      Value<int>? durationMs,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AudioNoteRowsCompanion(
      id: id ?? this.id,
      annotationId: annotationId ?? this.annotationId,
      localFilePath: localFilePath ?? this.localFilePath,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (annotationId.present) {
      map['annotation_id'] = Variable<String>(annotationId.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioNoteRowsCompanion(')
          ..write('id: $id, ')
          ..write('annotationId: $annotationId, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeasurementRowsTable extends MeasurementRows
    with TableInfo<$MeasurementRowsTable, MeasurementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeasurementRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _drawingIdMeta =
      const VerificationMeta('drawingId');
  @override
  late final GeneratedColumn<String> drawingId = GeneratedColumn<String>(
      'drawing_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pointsJsonMeta =
      const VerificationMeta('pointsJson');
  @override
  late final GeneratedColumn<String> pointsJson = GeneratedColumn<String>(
      'points_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _annotationIdsJsonMeta =
      const VerificationMeta('annotationIdsJson');
  @override
  late final GeneratedColumn<String> annotationIdsJson =
      GeneratedColumn<String>('annotation_ids_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, drawingId, type, pointsJson, annotationIdsJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measurement_rows';
  @override
  VerificationContext validateIntegrity(Insertable<MeasurementRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('drawing_id')) {
      context.handle(_drawingIdMeta,
          drawingId.isAcceptableOrUnknown(data['drawing_id']!, _drawingIdMeta));
    } else if (isInserting) {
      context.missing(_drawingIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('points_json')) {
      context.handle(
          _pointsJsonMeta,
          pointsJson.isAcceptableOrUnknown(
              data['points_json']!, _pointsJsonMeta));
    } else if (isInserting) {
      context.missing(_pointsJsonMeta);
    }
    if (data.containsKey('annotation_ids_json')) {
      context.handle(
          _annotationIdsJsonMeta,
          annotationIdsJson.isAcceptableOrUnknown(
              data['annotation_ids_json']!, _annotationIdsJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeasurementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeasurementRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      drawingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drawing_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      pointsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}points_json'])!,
      annotationIdsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}annotation_ids_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MeasurementRowsTable createAlias(String alias) {
    return $MeasurementRowsTable(attachedDatabase, alias);
  }
}

class MeasurementRow extends DataClass implements Insertable<MeasurementRow> {
  final String id;
  final String drawingId;
  final String type;
  final String pointsJson;
  final String? annotationIdsJson;
  final DateTime createdAt;
  const MeasurementRow(
      {required this.id,
      required this.drawingId,
      required this.type,
      required this.pointsJson,
      this.annotationIdsJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['drawing_id'] = Variable<String>(drawingId);
    map['type'] = Variable<String>(type);
    map['points_json'] = Variable<String>(pointsJson);
    if (!nullToAbsent || annotationIdsJson != null) {
      map['annotation_ids_json'] = Variable<String>(annotationIdsJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MeasurementRowsCompanion toCompanion(bool nullToAbsent) {
    return MeasurementRowsCompanion(
      id: Value(id),
      drawingId: Value(drawingId),
      type: Value(type),
      pointsJson: Value(pointsJson),
      annotationIdsJson: annotationIdsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationIdsJson),
      createdAt: Value(createdAt),
    );
  }

  factory MeasurementRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeasurementRow(
      id: serializer.fromJson<String>(json['id']),
      drawingId: serializer.fromJson<String>(json['drawingId']),
      type: serializer.fromJson<String>(json['type']),
      pointsJson: serializer.fromJson<String>(json['pointsJson']),
      annotationIdsJson:
          serializer.fromJson<String?>(json['annotationIdsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'drawingId': serializer.toJson<String>(drawingId),
      'type': serializer.toJson<String>(type),
      'pointsJson': serializer.toJson<String>(pointsJson),
      'annotationIdsJson': serializer.toJson<String?>(annotationIdsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MeasurementRow copyWith(
          {String? id,
          String? drawingId,
          String? type,
          String? pointsJson,
          Value<String?> annotationIdsJson = const Value.absent(),
          DateTime? createdAt}) =>
      MeasurementRow(
        id: id ?? this.id,
        drawingId: drawingId ?? this.drawingId,
        type: type ?? this.type,
        pointsJson: pointsJson ?? this.pointsJson,
        annotationIdsJson: annotationIdsJson.present
            ? annotationIdsJson.value
            : this.annotationIdsJson,
        createdAt: createdAt ?? this.createdAt,
      );
  MeasurementRow copyWithCompanion(MeasurementRowsCompanion data) {
    return MeasurementRow(
      id: data.id.present ? data.id.value : this.id,
      drawingId: data.drawingId.present ? data.drawingId.value : this.drawingId,
      type: data.type.present ? data.type.value : this.type,
      pointsJson:
          data.pointsJson.present ? data.pointsJson.value : this.pointsJson,
      annotationIdsJson: data.annotationIdsJson.present
          ? data.annotationIdsJson.value
          : this.annotationIdsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementRow(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('type: $type, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('annotationIdsJson: $annotationIdsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, drawingId, type, pointsJson, annotationIdsJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeasurementRow &&
          other.id == this.id &&
          other.drawingId == this.drawingId &&
          other.type == this.type &&
          other.pointsJson == this.pointsJson &&
          other.annotationIdsJson == this.annotationIdsJson &&
          other.createdAt == this.createdAt);
}

class MeasurementRowsCompanion extends UpdateCompanion<MeasurementRow> {
  final Value<String> id;
  final Value<String> drawingId;
  final Value<String> type;
  final Value<String> pointsJson;
  final Value<String?> annotationIdsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MeasurementRowsCompanion({
    this.id = const Value.absent(),
    this.drawingId = const Value.absent(),
    this.type = const Value.absent(),
    this.pointsJson = const Value.absent(),
    this.annotationIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeasurementRowsCompanion.insert({
    required String id,
    required String drawingId,
    required String type,
    required String pointsJson,
    this.annotationIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        drawingId = Value(drawingId),
        type = Value(type),
        pointsJson = Value(pointsJson);
  static Insertable<MeasurementRow> custom({
    Expression<String>? id,
    Expression<String>? drawingId,
    Expression<String>? type,
    Expression<String>? pointsJson,
    Expression<String>? annotationIdsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (drawingId != null) 'drawing_id': drawingId,
      if (type != null) 'type': type,
      if (pointsJson != null) 'points_json': pointsJson,
      if (annotationIdsJson != null) 'annotation_ids_json': annotationIdsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeasurementRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? drawingId,
      Value<String>? type,
      Value<String>? pointsJson,
      Value<String?>? annotationIdsJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MeasurementRowsCompanion(
      id: id ?? this.id,
      drawingId: drawingId ?? this.drawingId,
      type: type ?? this.type,
      pointsJson: pointsJson ?? this.pointsJson,
      annotationIdsJson: annotationIdsJson ?? this.annotationIdsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (drawingId.present) {
      map['drawing_id'] = Variable<String>(drawingId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (pointsJson.present) {
      map['points_json'] = Variable<String>(pointsJson.value);
    }
    if (annotationIdsJson.present) {
      map['annotation_ids_json'] = Variable<String>(annotationIdsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementRowsCompanion(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('type: $type, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('annotationIdsJson: $annotationIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DrawnObjectRowsTable extends DrawnObjectRows
    with TableInfo<$DrawnObjectRowsTable, DrawnObjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DrawnObjectRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _drawingIdMeta =
      const VerificationMeta('drawingId');
  @override
  late final GeneratedColumn<String> drawingId = GeneratedColumn<String>(
      'drawing_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pointsJsonMeta =
      const VerificationMeta('pointsJson');
  @override
  late final GeneratedColumn<String> pointsJson = GeneratedColumn<String>(
      'points_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bulgesJsonMeta =
      const VerificationMeta('bulgesJson');
  @override
  late final GeneratedColumn<String> bulgesJson = GeneratedColumn<String>(
      'bulges_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
      'height', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
      'color', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(kDrawnDefaultColor));
  static const VerificationMeta _strokePxMeta =
      const VerificationMeta('strokePx');
  @override
  late final GeneratedColumn<double> strokePx = GeneratedColumn<double>(
      'stroke_px', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(kDrawnDefaultStrokePx));
  static const VerificationMeta _rotationMeta =
      const VerificationMeta('rotation');
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
      'rotation', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
      'layer', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(kDefaultDrawnLayer));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        drawingId,
        type,
        pointsJson,
        bulgesJson,
        content,
        height,
        color,
        strokePx,
        rotation,
        layer,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drawn_object_rows';
  @override
  VerificationContext validateIntegrity(Insertable<DrawnObjectRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('drawing_id')) {
      context.handle(_drawingIdMeta,
          drawingId.isAcceptableOrUnknown(data['drawing_id']!, _drawingIdMeta));
    } else if (isInserting) {
      context.missing(_drawingIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('points_json')) {
      context.handle(
          _pointsJsonMeta,
          pointsJson.isAcceptableOrUnknown(
              data['points_json']!, _pointsJsonMeta));
    } else if (isInserting) {
      context.missing(_pointsJsonMeta);
    }
    if (data.containsKey('bulges_json')) {
      context.handle(
          _bulgesJsonMeta,
          bulgesJson.isAcceptableOrUnknown(
              data['bulges_json']!, _bulgesJsonMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('stroke_px')) {
      context.handle(_strokePxMeta,
          strokePx.isAcceptableOrUnknown(data['stroke_px']!, _strokePxMeta));
    }
    if (data.containsKey('rotation')) {
      context.handle(_rotationMeta,
          rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta));
    }
    if (data.containsKey('layer')) {
      context.handle(
          _layerMeta, layer.isAcceptableOrUnknown(data['layer']!, _layerMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DrawnObjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DrawnObjectRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      drawingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drawing_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      pointsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}points_json'])!,
      bulgesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bulges_json']),
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}height']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color'])!,
      strokePx: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stroke_px'])!,
      rotation: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rotation'])!,
      layer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layer'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DrawnObjectRowsTable createAlias(String alias) {
    return $DrawnObjectRowsTable(attachedDatabase, alias);
  }
}

class DrawnObjectRow extends DataClass implements Insertable<DrawnObjectRow> {
  final String id;
  final String drawingId;
  final String type;
  final String pointsJson;
  final String? bulgesJson;
  final String? content;
  final double? height;
  final int color;
  final double strokePx;
  final double rotation;
  final String layer;
  final DateTime createdAt;
  const DrawnObjectRow(
      {required this.id,
      required this.drawingId,
      required this.type,
      required this.pointsJson,
      this.bulgesJson,
      this.content,
      this.height,
      required this.color,
      required this.strokePx,
      required this.rotation,
      required this.layer,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['drawing_id'] = Variable<String>(drawingId);
    map['type'] = Variable<String>(type);
    map['points_json'] = Variable<String>(pointsJson);
    if (!nullToAbsent || bulgesJson != null) {
      map['bulges_json'] = Variable<String>(bulgesJson);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<double>(height);
    }
    map['color'] = Variable<int>(color);
    map['stroke_px'] = Variable<double>(strokePx);
    map['rotation'] = Variable<double>(rotation);
    map['layer'] = Variable<String>(layer);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DrawnObjectRowsCompanion toCompanion(bool nullToAbsent) {
    return DrawnObjectRowsCompanion(
      id: Value(id),
      drawingId: Value(drawingId),
      type: Value(type),
      pointsJson: Value(pointsJson),
      bulgesJson: bulgesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(bulgesJson),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      color: Value(color),
      strokePx: Value(strokePx),
      rotation: Value(rotation),
      layer: Value(layer),
      createdAt: Value(createdAt),
    );
  }

  factory DrawnObjectRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DrawnObjectRow(
      id: serializer.fromJson<String>(json['id']),
      drawingId: serializer.fromJson<String>(json['drawingId']),
      type: serializer.fromJson<String>(json['type']),
      pointsJson: serializer.fromJson<String>(json['pointsJson']),
      bulgesJson: serializer.fromJson<String?>(json['bulgesJson']),
      content: serializer.fromJson<String?>(json['content']),
      height: serializer.fromJson<double?>(json['height']),
      color: serializer.fromJson<int>(json['color']),
      strokePx: serializer.fromJson<double>(json['strokePx']),
      rotation: serializer.fromJson<double>(json['rotation']),
      layer: serializer.fromJson<String>(json['layer']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'drawingId': serializer.toJson<String>(drawingId),
      'type': serializer.toJson<String>(type),
      'pointsJson': serializer.toJson<String>(pointsJson),
      'bulgesJson': serializer.toJson<String?>(bulgesJson),
      'content': serializer.toJson<String?>(content),
      'height': serializer.toJson<double?>(height),
      'color': serializer.toJson<int>(color),
      'strokePx': serializer.toJson<double>(strokePx),
      'rotation': serializer.toJson<double>(rotation),
      'layer': serializer.toJson<String>(layer),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DrawnObjectRow copyWith(
          {String? id,
          String? drawingId,
          String? type,
          String? pointsJson,
          Value<String?> bulgesJson = const Value.absent(),
          Value<String?> content = const Value.absent(),
          Value<double?> height = const Value.absent(),
          int? color,
          double? strokePx,
          double? rotation,
          String? layer,
          DateTime? createdAt}) =>
      DrawnObjectRow(
        id: id ?? this.id,
        drawingId: drawingId ?? this.drawingId,
        type: type ?? this.type,
        pointsJson: pointsJson ?? this.pointsJson,
        bulgesJson: bulgesJson.present ? bulgesJson.value : this.bulgesJson,
        content: content.present ? content.value : this.content,
        height: height.present ? height.value : this.height,
        color: color ?? this.color,
        strokePx: strokePx ?? this.strokePx,
        rotation: rotation ?? this.rotation,
        layer: layer ?? this.layer,
        createdAt: createdAt ?? this.createdAt,
      );
  DrawnObjectRow copyWithCompanion(DrawnObjectRowsCompanion data) {
    return DrawnObjectRow(
      id: data.id.present ? data.id.value : this.id,
      drawingId: data.drawingId.present ? data.drawingId.value : this.drawingId,
      type: data.type.present ? data.type.value : this.type,
      pointsJson:
          data.pointsJson.present ? data.pointsJson.value : this.pointsJson,
      bulgesJson:
          data.bulgesJson.present ? data.bulgesJson.value : this.bulgesJson,
      content: data.content.present ? data.content.value : this.content,
      height: data.height.present ? data.height.value : this.height,
      color: data.color.present ? data.color.value : this.color,
      strokePx: data.strokePx.present ? data.strokePx.value : this.strokePx,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      layer: data.layer.present ? data.layer.value : this.layer,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DrawnObjectRow(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('type: $type, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('bulgesJson: $bulgesJson, ')
          ..write('content: $content, ')
          ..write('height: $height, ')
          ..write('color: $color, ')
          ..write('strokePx: $strokePx, ')
          ..write('rotation: $rotation, ')
          ..write('layer: $layer, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, drawingId, type, pointsJson, bulgesJson,
      content, height, color, strokePx, rotation, layer, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DrawnObjectRow &&
          other.id == this.id &&
          other.drawingId == this.drawingId &&
          other.type == this.type &&
          other.pointsJson == this.pointsJson &&
          other.bulgesJson == this.bulgesJson &&
          other.content == this.content &&
          other.height == this.height &&
          other.color == this.color &&
          other.strokePx == this.strokePx &&
          other.rotation == this.rotation &&
          other.layer == this.layer &&
          other.createdAt == this.createdAt);
}

class DrawnObjectRowsCompanion extends UpdateCompanion<DrawnObjectRow> {
  final Value<String> id;
  final Value<String> drawingId;
  final Value<String> type;
  final Value<String> pointsJson;
  final Value<String?> bulgesJson;
  final Value<String?> content;
  final Value<double?> height;
  final Value<int> color;
  final Value<double> strokePx;
  final Value<double> rotation;
  final Value<String> layer;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DrawnObjectRowsCompanion({
    this.id = const Value.absent(),
    this.drawingId = const Value.absent(),
    this.type = const Value.absent(),
    this.pointsJson = const Value.absent(),
    this.bulgesJson = const Value.absent(),
    this.content = const Value.absent(),
    this.height = const Value.absent(),
    this.color = const Value.absent(),
    this.strokePx = const Value.absent(),
    this.rotation = const Value.absent(),
    this.layer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DrawnObjectRowsCompanion.insert({
    required String id,
    required String drawingId,
    required String type,
    required String pointsJson,
    this.bulgesJson = const Value.absent(),
    this.content = const Value.absent(),
    this.height = const Value.absent(),
    this.color = const Value.absent(),
    this.strokePx = const Value.absent(),
    this.rotation = const Value.absent(),
    this.layer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        drawingId = Value(drawingId),
        type = Value(type),
        pointsJson = Value(pointsJson);
  static Insertable<DrawnObjectRow> custom({
    Expression<String>? id,
    Expression<String>? drawingId,
    Expression<String>? type,
    Expression<String>? pointsJson,
    Expression<String>? bulgesJson,
    Expression<String>? content,
    Expression<double>? height,
    Expression<int>? color,
    Expression<double>? strokePx,
    Expression<double>? rotation,
    Expression<String>? layer,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (drawingId != null) 'drawing_id': drawingId,
      if (type != null) 'type': type,
      if (pointsJson != null) 'points_json': pointsJson,
      if (bulgesJson != null) 'bulges_json': bulgesJson,
      if (content != null) 'content': content,
      if (height != null) 'height': height,
      if (color != null) 'color': color,
      if (strokePx != null) 'stroke_px': strokePx,
      if (rotation != null) 'rotation': rotation,
      if (layer != null) 'layer': layer,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DrawnObjectRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? drawingId,
      Value<String>? type,
      Value<String>? pointsJson,
      Value<String?>? bulgesJson,
      Value<String?>? content,
      Value<double?>? height,
      Value<int>? color,
      Value<double>? strokePx,
      Value<double>? rotation,
      Value<String>? layer,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return DrawnObjectRowsCompanion(
      id: id ?? this.id,
      drawingId: drawingId ?? this.drawingId,
      type: type ?? this.type,
      pointsJson: pointsJson ?? this.pointsJson,
      bulgesJson: bulgesJson ?? this.bulgesJson,
      content: content ?? this.content,
      height: height ?? this.height,
      color: color ?? this.color,
      strokePx: strokePx ?? this.strokePx,
      rotation: rotation ?? this.rotation,
      layer: layer ?? this.layer,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (drawingId.present) {
      map['drawing_id'] = Variable<String>(drawingId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (pointsJson.present) {
      map['points_json'] = Variable<String>(pointsJson.value);
    }
    if (bulgesJson.present) {
      map['bulges_json'] = Variable<String>(bulgesJson.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (strokePx.present) {
      map['stroke_px'] = Variable<double>(strokePx.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<double>(rotation.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DrawnObjectRowsCompanion(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('type: $type, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('bulgesJson: $bulgesJson, ')
          ..write('content: $content, ')
          ..write('height: $height, ')
          ..write('color: $color, ')
          ..write('strokePx: $strokePx, ')
          ..write('rotation: $rotation, ')
          ..write('layer: $layer, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoryEventRowsTable extends HistoryEventRows
    with TableInfo<$HistoryEventRowsTable, HistoryEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryEventRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _drawingIdMeta =
      const VerificationMeta('drawingId');
  @override
  late final GeneratedColumn<String> drawingId = GeneratedColumn<String>(
      'drawing_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _annotationIdMeta =
      const VerificationMeta('annotationId');
  @override
  late final GeneratedColumn<String> annotationId = GeneratedColumn<String>(
      'annotation_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _detailsJsonMeta =
      const VerificationMeta('detailsJson');
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
      'details_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, drawingId, annotationId, type, summary, detailsJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_event_rows';
  @override
  VerificationContext validateIntegrity(Insertable<HistoryEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('drawing_id')) {
      context.handle(_drawingIdMeta,
          drawingId.isAcceptableOrUnknown(data['drawing_id']!, _drawingIdMeta));
    } else if (isInserting) {
      context.missing(_drawingIdMeta);
    }
    if (data.containsKey('annotation_id')) {
      context.handle(
          _annotationIdMeta,
          annotationId.isAcceptableOrUnknown(
              data['annotation_id']!, _annotationIdMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('details_json')) {
      context.handle(
          _detailsJsonMeta,
          detailsJson.isAcceptableOrUnknown(
              data['details_json']!, _detailsJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      drawingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drawing_id'])!,
      annotationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}annotation_id']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary'])!,
      detailsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}details_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $HistoryEventRowsTable createAlias(String alias) {
    return $HistoryEventRowsTable(attachedDatabase, alias);
  }
}

class HistoryEventRow extends DataClass implements Insertable<HistoryEventRow> {
  final String id;
  final String drawingId;
  final String? annotationId;
  final String type;
  final String summary;
  final String? detailsJson;
  final DateTime createdAt;
  const HistoryEventRow(
      {required this.id,
      required this.drawingId,
      this.annotationId,
      required this.type,
      required this.summary,
      this.detailsJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['drawing_id'] = Variable<String>(drawingId);
    if (!nullToAbsent || annotationId != null) {
      map['annotation_id'] = Variable<String>(annotationId);
    }
    map['type'] = Variable<String>(type);
    map['summary'] = Variable<String>(summary);
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HistoryEventRowsCompanion toCompanion(bool nullToAbsent) {
    return HistoryEventRowsCompanion(
      id: Value(id),
      drawingId: Value(drawingId),
      annotationId: annotationId == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationId),
      type: Value(type),
      summary: Value(summary),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      createdAt: Value(createdAt),
    );
  }

  factory HistoryEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryEventRow(
      id: serializer.fromJson<String>(json['id']),
      drawingId: serializer.fromJson<String>(json['drawingId']),
      annotationId: serializer.fromJson<String?>(json['annotationId']),
      type: serializer.fromJson<String>(json['type']),
      summary: serializer.fromJson<String>(json['summary']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'drawingId': serializer.toJson<String>(drawingId),
      'annotationId': serializer.toJson<String?>(annotationId),
      'type': serializer.toJson<String>(type),
      'summary': serializer.toJson<String>(summary),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HistoryEventRow copyWith(
          {String? id,
          String? drawingId,
          Value<String?> annotationId = const Value.absent(),
          String? type,
          String? summary,
          Value<String?> detailsJson = const Value.absent(),
          DateTime? createdAt}) =>
      HistoryEventRow(
        id: id ?? this.id,
        drawingId: drawingId ?? this.drawingId,
        annotationId:
            annotationId.present ? annotationId.value : this.annotationId,
        type: type ?? this.type,
        summary: summary ?? this.summary,
        detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
        createdAt: createdAt ?? this.createdAt,
      );
  HistoryEventRow copyWithCompanion(HistoryEventRowsCompanion data) {
    return HistoryEventRow(
      id: data.id.present ? data.id.value : this.id,
      drawingId: data.drawingId.present ? data.drawingId.value : this.drawingId,
      annotationId: data.annotationId.present
          ? data.annotationId.value
          : this.annotationId,
      type: data.type.present ? data.type.value : this.type,
      summary: data.summary.present ? data.summary.value : this.summary,
      detailsJson:
          data.detailsJson.present ? data.detailsJson.value : this.detailsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEventRow(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('annotationId: $annotationId, ')
          ..write('type: $type, ')
          ..write('summary: $summary, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, drawingId, annotationId, type, summary, detailsJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryEventRow &&
          other.id == this.id &&
          other.drawingId == this.drawingId &&
          other.annotationId == this.annotationId &&
          other.type == this.type &&
          other.summary == this.summary &&
          other.detailsJson == this.detailsJson &&
          other.createdAt == this.createdAt);
}

class HistoryEventRowsCompanion extends UpdateCompanion<HistoryEventRow> {
  final Value<String> id;
  final Value<String> drawingId;
  final Value<String?> annotationId;
  final Value<String> type;
  final Value<String> summary;
  final Value<String?> detailsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HistoryEventRowsCompanion({
    this.id = const Value.absent(),
    this.drawingId = const Value.absent(),
    this.annotationId = const Value.absent(),
    this.type = const Value.absent(),
    this.summary = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoryEventRowsCompanion.insert({
    required String id,
    required String drawingId,
    this.annotationId = const Value.absent(),
    required String type,
    required String summary,
    this.detailsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        drawingId = Value(drawingId),
        type = Value(type),
        summary = Value(summary);
  static Insertable<HistoryEventRow> custom({
    Expression<String>? id,
    Expression<String>? drawingId,
    Expression<String>? annotationId,
    Expression<String>? type,
    Expression<String>? summary,
    Expression<String>? detailsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (drawingId != null) 'drawing_id': drawingId,
      if (annotationId != null) 'annotation_id': annotationId,
      if (type != null) 'type': type,
      if (summary != null) 'summary': summary,
      if (detailsJson != null) 'details_json': detailsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoryEventRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? drawingId,
      Value<String?>? annotationId,
      Value<String>? type,
      Value<String>? summary,
      Value<String?>? detailsJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return HistoryEventRowsCompanion(
      id: id ?? this.id,
      drawingId: drawingId ?? this.drawingId,
      annotationId: annotationId ?? this.annotationId,
      type: type ?? this.type,
      summary: summary ?? this.summary,
      detailsJson: detailsJson ?? this.detailsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (drawingId.present) {
      map['drawing_id'] = Variable<String>(drawingId.value);
    }
    if (annotationId.present) {
      map['annotation_id'] = Variable<String>(annotationId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEventRowsCompanion(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('annotationId: $annotationId, ')
          ..write('type: $type, ')
          ..write('summary: $summary, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectVersionRowsTable extends ProjectVersionRows
    with TableInfo<$ProjectVersionRowsTable, ProjectVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectVersionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _drawingIdMeta =
      const VerificationMeta('drawingId');
  @override
  late final GeneratedColumn<String> drawingId = GeneratedColumn<String>(
      'drawing_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _annotationsCountMeta =
      const VerificationMeta('annotationsCount');
  @override
  late final GeneratedColumn<int> annotationsCount = GeneratedColumn<int>(
      'annotations_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _measurementsCountMeta =
      const VerificationMeta('measurementsCount');
  @override
  late final GeneratedColumn<int> measurementsCount = GeneratedColumn<int>(
      'measurements_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _photosCountMeta =
      const VerificationMeta('photosCount');
  @override
  late final GeneratedColumn<int> photosCount = GeneratedColumn<int>(
      'photos_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _audioCountMeta =
      const VerificationMeta('audioCount');
  @override
  late final GeneratedColumn<int> audioCount = GeneratedColumn<int>(
      'audio_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        drawingId,
        label,
        filePath,
        sizeBytes,
        annotationsCount,
        measurementsCount,
        photosCount,
        audioCount,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_version_rows';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectVersionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('drawing_id')) {
      context.handle(_drawingIdMeta,
          drawingId.isAcceptableOrUnknown(data['drawing_id']!, _drawingIdMeta));
    } else if (isInserting) {
      context.missing(_drawingIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('annotations_count')) {
      context.handle(
          _annotationsCountMeta,
          annotationsCount.isAcceptableOrUnknown(
              data['annotations_count']!, _annotationsCountMeta));
    }
    if (data.containsKey('measurements_count')) {
      context.handle(
          _measurementsCountMeta,
          measurementsCount.isAcceptableOrUnknown(
              data['measurements_count']!, _measurementsCountMeta));
    }
    if (data.containsKey('photos_count')) {
      context.handle(
          _photosCountMeta,
          photosCount.isAcceptableOrUnknown(
              data['photos_count']!, _photosCountMeta));
    }
    if (data.containsKey('audio_count')) {
      context.handle(
          _audioCountMeta,
          audioCount.isAcceptableOrUnknown(
              data['audio_count']!, _audioCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectVersionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      drawingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drawing_id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      annotationsCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}annotations_count'])!,
      measurementsCount: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}measurements_count'])!,
      photosCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}photos_count'])!,
      audioCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}audio_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ProjectVersionRowsTable createAlias(String alias) {
    return $ProjectVersionRowsTable(attachedDatabase, alias);
  }
}

class ProjectVersionRow extends DataClass
    implements Insertable<ProjectVersionRow> {
  final String id;
  final String drawingId;
  final String label;
  final String filePath;
  final int sizeBytes;
  final int annotationsCount;
  final int measurementsCount;
  final int photosCount;
  final int audioCount;
  final DateTime createdAt;
  const ProjectVersionRow(
      {required this.id,
      required this.drawingId,
      required this.label,
      required this.filePath,
      required this.sizeBytes,
      required this.annotationsCount,
      required this.measurementsCount,
      required this.photosCount,
      required this.audioCount,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['drawing_id'] = Variable<String>(drawingId);
    map['label'] = Variable<String>(label);
    map['file_path'] = Variable<String>(filePath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['annotations_count'] = Variable<int>(annotationsCount);
    map['measurements_count'] = Variable<int>(measurementsCount);
    map['photos_count'] = Variable<int>(photosCount);
    map['audio_count'] = Variable<int>(audioCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProjectVersionRowsCompanion toCompanion(bool nullToAbsent) {
    return ProjectVersionRowsCompanion(
      id: Value(id),
      drawingId: Value(drawingId),
      label: Value(label),
      filePath: Value(filePath),
      sizeBytes: Value(sizeBytes),
      annotationsCount: Value(annotationsCount),
      measurementsCount: Value(measurementsCount),
      photosCount: Value(photosCount),
      audioCount: Value(audioCount),
      createdAt: Value(createdAt),
    );
  }

  factory ProjectVersionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectVersionRow(
      id: serializer.fromJson<String>(json['id']),
      drawingId: serializer.fromJson<String>(json['drawingId']),
      label: serializer.fromJson<String>(json['label']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      annotationsCount: serializer.fromJson<int>(json['annotationsCount']),
      measurementsCount: serializer.fromJson<int>(json['measurementsCount']),
      photosCount: serializer.fromJson<int>(json['photosCount']),
      audioCount: serializer.fromJson<int>(json['audioCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'drawingId': serializer.toJson<String>(drawingId),
      'label': serializer.toJson<String>(label),
      'filePath': serializer.toJson<String>(filePath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'annotationsCount': serializer.toJson<int>(annotationsCount),
      'measurementsCount': serializer.toJson<int>(measurementsCount),
      'photosCount': serializer.toJson<int>(photosCount),
      'audioCount': serializer.toJson<int>(audioCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProjectVersionRow copyWith(
          {String? id,
          String? drawingId,
          String? label,
          String? filePath,
          int? sizeBytes,
          int? annotationsCount,
          int? measurementsCount,
          int? photosCount,
          int? audioCount,
          DateTime? createdAt}) =>
      ProjectVersionRow(
        id: id ?? this.id,
        drawingId: drawingId ?? this.drawingId,
        label: label ?? this.label,
        filePath: filePath ?? this.filePath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        annotationsCount: annotationsCount ?? this.annotationsCount,
        measurementsCount: measurementsCount ?? this.measurementsCount,
        photosCount: photosCount ?? this.photosCount,
        audioCount: audioCount ?? this.audioCount,
        createdAt: createdAt ?? this.createdAt,
      );
  ProjectVersionRow copyWithCompanion(ProjectVersionRowsCompanion data) {
    return ProjectVersionRow(
      id: data.id.present ? data.id.value : this.id,
      drawingId: data.drawingId.present ? data.drawingId.value : this.drawingId,
      label: data.label.present ? data.label.value : this.label,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      annotationsCount: data.annotationsCount.present
          ? data.annotationsCount.value
          : this.annotationsCount,
      measurementsCount: data.measurementsCount.present
          ? data.measurementsCount.value
          : this.measurementsCount,
      photosCount:
          data.photosCount.present ? data.photosCount.value : this.photosCount,
      audioCount:
          data.audioCount.present ? data.audioCount.value : this.audioCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectVersionRow(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('label: $label, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('annotationsCount: $annotationsCount, ')
          ..write('measurementsCount: $measurementsCount, ')
          ..write('photosCount: $photosCount, ')
          ..write('audioCount: $audioCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, drawingId, label, filePath, sizeBytes,
      annotationsCount, measurementsCount, photosCount, audioCount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectVersionRow &&
          other.id == this.id &&
          other.drawingId == this.drawingId &&
          other.label == this.label &&
          other.filePath == this.filePath &&
          other.sizeBytes == this.sizeBytes &&
          other.annotationsCount == this.annotationsCount &&
          other.measurementsCount == this.measurementsCount &&
          other.photosCount == this.photosCount &&
          other.audioCount == this.audioCount &&
          other.createdAt == this.createdAt);
}

class ProjectVersionRowsCompanion extends UpdateCompanion<ProjectVersionRow> {
  final Value<String> id;
  final Value<String> drawingId;
  final Value<String> label;
  final Value<String> filePath;
  final Value<int> sizeBytes;
  final Value<int> annotationsCount;
  final Value<int> measurementsCount;
  final Value<int> photosCount;
  final Value<int> audioCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProjectVersionRowsCompanion({
    this.id = const Value.absent(),
    this.drawingId = const Value.absent(),
    this.label = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.annotationsCount = const Value.absent(),
    this.measurementsCount = const Value.absent(),
    this.photosCount = const Value.absent(),
    this.audioCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectVersionRowsCompanion.insert({
    required String id,
    required String drawingId,
    required String label,
    required String filePath,
    this.sizeBytes = const Value.absent(),
    this.annotationsCount = const Value.absent(),
    this.measurementsCount = const Value.absent(),
    this.photosCount = const Value.absent(),
    this.audioCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        drawingId = Value(drawingId),
        label = Value(label),
        filePath = Value(filePath);
  static Insertable<ProjectVersionRow> custom({
    Expression<String>? id,
    Expression<String>? drawingId,
    Expression<String>? label,
    Expression<String>? filePath,
    Expression<int>? sizeBytes,
    Expression<int>? annotationsCount,
    Expression<int>? measurementsCount,
    Expression<int>? photosCount,
    Expression<int>? audioCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (drawingId != null) 'drawing_id': drawingId,
      if (label != null) 'label': label,
      if (filePath != null) 'file_path': filePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (annotationsCount != null) 'annotations_count': annotationsCount,
      if (measurementsCount != null) 'measurements_count': measurementsCount,
      if (photosCount != null) 'photos_count': photosCount,
      if (audioCount != null) 'audio_count': audioCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectVersionRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? drawingId,
      Value<String>? label,
      Value<String>? filePath,
      Value<int>? sizeBytes,
      Value<int>? annotationsCount,
      Value<int>? measurementsCount,
      Value<int>? photosCount,
      Value<int>? audioCount,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ProjectVersionRowsCompanion(
      id: id ?? this.id,
      drawingId: drawingId ?? this.drawingId,
      label: label ?? this.label,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      annotationsCount: annotationsCount ?? this.annotationsCount,
      measurementsCount: measurementsCount ?? this.measurementsCount,
      photosCount: photosCount ?? this.photosCount,
      audioCount: audioCount ?? this.audioCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (drawingId.present) {
      map['drawing_id'] = Variable<String>(drawingId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (annotationsCount.present) {
      map['annotations_count'] = Variable<int>(annotationsCount.value);
    }
    if (measurementsCount.present) {
      map['measurements_count'] = Variable<int>(measurementsCount.value);
    }
    if (photosCount.present) {
      map['photos_count'] = Variable<int>(photosCount.value);
    }
    if (audioCount.present) {
      map['audio_count'] = Variable<int>(audioCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectVersionRowsCompanion(')
          ..write('id: $id, ')
          ..write('drawingId: $drawingId, ')
          ..write('label: $label, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('annotationsCount: $annotationsCount, ')
          ..write('measurementsCount: $measurementsCount, ')
          ..write('photosCount: $photosCount, ')
          ..write('audioCount: $audioCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $DrawingsTable drawings = $DrawingsTable(this);
  late final $AnnotationRowsTable annotationRows = $AnnotationRowsTable(this);
  late final $PhotoRowsTable photoRows = $PhotoRowsTable(this);
  late final $AudioNoteRowsTable audioNoteRows = $AudioNoteRowsTable(this);
  late final $MeasurementRowsTable measurementRows =
      $MeasurementRowsTable(this);
  late final $DrawnObjectRowsTable drawnObjectRows =
      $DrawnObjectRowsTable(this);
  late final $HistoryEventRowsTable historyEventRows =
      $HistoryEventRowsTable(this);
  late final $ProjectVersionRowsTable projectVersionRows =
      $ProjectVersionRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        projects,
        drawings,
        annotationRows,
        photoRows,
        audioNoteRows,
        measurementRows,
        drawnObjectRows,
        historyEventRows,
        projectVersionRows
      ];
}

typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  Value<String?> parentId,
  required String name,
  Value<DateTime> createdAt,
  Value<bool> isDeleted,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String?> parentId,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<bool> isDeleted,
  Value<int> rowid,
});

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$ProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
    Project,
    PrefetchHooks Function()> {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion(
            id: id,
            parentId: parentId,
            name: name,
            createdAt: createdAt,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> parentId = const Value.absent(),
            required String name,
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion.insert(
            id: id,
            parentId: parentId,
            name: name,
            createdAt: createdAt,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProjectsTable, Project>(table),
                    BaseReferences<_$AppDatabase, $ProjectsTable, Project>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProjectsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
    Project,
    PrefetchHooks Function()>;
typedef $$DrawingsTableCreateCompanionBuilder = DrawingsCompanion Function({
  required String id,
  required String projectId,
  required String name,
  required String localFilePath,
  Value<String> units,
  Value<int> nextAnnotationNumber,
  Value<String?> contentHash,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$DrawingsTableUpdateCompanionBuilder = DrawingsCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> name,
  Value<String> localFilePath,
  Value<String> units,
  Value<int> nextAnnotationNumber,
  Value<String?> contentHash,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$DrawingsTableFilterComposer
    extends Composer<_$AppDatabase, $DrawingsTable> {
  $$DrawingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextAnnotationNumber => $composableBuilder(
      column: $table.nextAnnotationNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DrawingsTableOrderingComposer
    extends Composer<_$AppDatabase, $DrawingsTable> {
  $$DrawingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextAnnotationNumber => $composableBuilder(
      column: $table.nextAnnotationNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DrawingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DrawingsTable> {
  $$DrawingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => column);

  GeneratedColumn<String> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<int> get nextAnnotationNumber => $composableBuilder(
      column: $table.nextAnnotationNumber, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DrawingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DrawingsTable,
    Drawing,
    $$DrawingsTableFilterComposer,
    $$DrawingsTableOrderingComposer,
    $$DrawingsTableAnnotationComposer,
    $$DrawingsTableCreateCompanionBuilder,
    $$DrawingsTableUpdateCompanionBuilder,
    (Drawing, BaseReferences<_$AppDatabase, $DrawingsTable, Drawing>),
    Drawing,
    PrefetchHooks Function()> {
  $$DrawingsTableTableManager(_$AppDatabase db, $DrawingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DrawingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DrawingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DrawingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> localFilePath = const Value.absent(),
            Value<String> units = const Value.absent(),
            Value<int> nextAnnotationNumber = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DrawingsCompanion(
            id: id,
            projectId: projectId,
            name: name,
            localFilePath: localFilePath,
            units: units,
            nextAnnotationNumber: nextAnnotationNumber,
            contentHash: contentHash,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String name,
            required String localFilePath,
            Value<String> units = const Value.absent(),
            Value<int> nextAnnotationNumber = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DrawingsCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            localFilePath: localFilePath,
            units: units,
            nextAnnotationNumber: nextAnnotationNumber,
            contentHash: contentHash,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DrawingsTable, Drawing>(table),
                    BaseReferences<_$AppDatabase, $DrawingsTable, Drawing>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DrawingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DrawingsTable,
    Drawing,
    $$DrawingsTableFilterComposer,
    $$DrawingsTableOrderingComposer,
    $$DrawingsTableAnnotationComposer,
    $$DrawingsTableCreateCompanionBuilder,
    $$DrawingsTableUpdateCompanionBuilder,
    (Drawing, BaseReferences<_$AppDatabase, $DrawingsTable, Drawing>),
    Drawing,
    PrefetchHooks Function()>;
typedef $$AnnotationRowsTableCreateCompanionBuilder = AnnotationRowsCompanion
    Function({
  required String id,
  required String drawingId,
  required int number,
  required double dxfX,
  required double dxfY,
  Value<double?> geoX,
  Value<double?> geoY,
  Value<double?> geoZ,
  Value<String?> code,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$AnnotationRowsTableUpdateCompanionBuilder = AnnotationRowsCompanion
    Function({
  Value<String> id,
  Value<String> drawingId,
  Value<int> number,
  Value<double> dxfX,
  Value<double> dxfY,
  Value<double?> geoX,
  Value<double?> geoY,
  Value<double?> geoZ,
  Value<String?> code,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$AnnotationRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationRowsTable> {
  $$AnnotationRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dxfX => $composableBuilder(
      column: $table.dxfX, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dxfY => $composableBuilder(
      column: $table.dxfY, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get geoX => $composableBuilder(
      column: $table.geoX, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get geoY => $composableBuilder(
      column: $table.geoY, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get geoZ => $composableBuilder(
      column: $table.geoZ, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$AnnotationRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationRowsTable> {
  $$AnnotationRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dxfX => $composableBuilder(
      column: $table.dxfX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dxfY => $composableBuilder(
      column: $table.dxfY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get geoX => $composableBuilder(
      column: $table.geoX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get geoY => $composableBuilder(
      column: $table.geoY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get geoZ => $composableBuilder(
      column: $table.geoZ, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$AnnotationRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationRowsTable> {
  $$AnnotationRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get drawingId =>
      $composableBuilder(column: $table.drawingId, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<double> get dxfX =>
      $composableBuilder(column: $table.dxfX, builder: (column) => column);

  GeneratedColumn<double> get dxfY =>
      $composableBuilder(column: $table.dxfY, builder: (column) => column);

  GeneratedColumn<double> get geoX =>
      $composableBuilder(column: $table.geoX, builder: (column) => column);

  GeneratedColumn<double> get geoY =>
      $composableBuilder(column: $table.geoY, builder: (column) => column);

  GeneratedColumn<double> get geoZ =>
      $composableBuilder(column: $table.geoZ, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AnnotationRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnotationRowsTable,
    AnnotationRow,
    $$AnnotationRowsTableFilterComposer,
    $$AnnotationRowsTableOrderingComposer,
    $$AnnotationRowsTableAnnotationComposer,
    $$AnnotationRowsTableCreateCompanionBuilder,
    $$AnnotationRowsTableUpdateCompanionBuilder,
    (
      AnnotationRow,
      BaseReferences<_$AppDatabase, $AnnotationRowsTable, AnnotationRow>
    ),
    AnnotationRow,
    PrefetchHooks Function()> {
  $$AnnotationRowsTableTableManager(
      _$AppDatabase db, $AnnotationRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> drawingId = const Value.absent(),
            Value<int> number = const Value.absent(),
            Value<double> dxfX = const Value.absent(),
            Value<double> dxfY = const Value.absent(),
            Value<double?> geoX = const Value.absent(),
            Value<double?> geoY = const Value.absent(),
            Value<double?> geoZ = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationRowsCompanion(
            id: id,
            drawingId: drawingId,
            number: number,
            dxfX: dxfX,
            dxfY: dxfY,
            geoX: geoX,
            geoY: geoY,
            geoZ: geoZ,
            code: code,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String drawingId,
            required int number,
            required double dxfX,
            required double dxfY,
            Value<double?> geoX = const Value.absent(),
            Value<double?> geoY = const Value.absent(),
            Value<double?> geoZ = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnotationRowsCompanion.insert(
            id: id,
            drawingId: drawingId,
            number: number,
            dxfX: dxfX,
            dxfY: dxfY,
            geoX: geoX,
            geoY: geoY,
            geoZ: geoZ,
            code: code,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AnnotationRowsTable, AnnotationRow>(table),
                    BaseReferences<_$AppDatabase, $AnnotationRowsTable,
                        AnnotationRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnnotationRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnotationRowsTable,
    AnnotationRow,
    $$AnnotationRowsTableFilterComposer,
    $$AnnotationRowsTableOrderingComposer,
    $$AnnotationRowsTableAnnotationComposer,
    $$AnnotationRowsTableCreateCompanionBuilder,
    $$AnnotationRowsTableUpdateCompanionBuilder,
    (
      AnnotationRow,
      BaseReferences<_$AppDatabase, $AnnotationRowsTable, AnnotationRow>
    ),
    AnnotationRow,
    PrefetchHooks Function()>;
typedef $$PhotoRowsTableCreateCompanionBuilder = PhotoRowsCompanion Function({
  required String id,
  required String annotationId,
  required String localFilePath,
  Value<String?> thumbnailPath,
  Value<DateTime> createdAt,
  Value<bool> isUploaded,
  Value<String?> fileUrl,
  Value<int> rowid,
});
typedef $$PhotoRowsTableUpdateCompanionBuilder = PhotoRowsCompanion Function({
  Value<String> id,
  Value<String> annotationId,
  Value<String> localFilePath,
  Value<String?> thumbnailPath,
  Value<DateTime> createdAt,
  Value<bool> isUploaded,
  Value<String?> fileUrl,
  Value<int> rowid,
});

class $$PhotoRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoRowsTable> {
  $$PhotoRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get annotationId => $composableBuilder(
      column: $table.annotationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUploaded => $composableBuilder(
      column: $table.isUploaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileUrl => $composableBuilder(
      column: $table.fileUrl, builder: (column) => ColumnFilters(column));
}

class $$PhotoRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoRowsTable> {
  $$PhotoRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get annotationId => $composableBuilder(
      column: $table.annotationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUploaded => $composableBuilder(
      column: $table.isUploaded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileUrl => $composableBuilder(
      column: $table.fileUrl, builder: (column) => ColumnOrderings(column));
}

class $$PhotoRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoRowsTable> {
  $$PhotoRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get annotationId => $composableBuilder(
      column: $table.annotationId, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isUploaded => $composableBuilder(
      column: $table.isUploaded, builder: (column) => column);

  GeneratedColumn<String> get fileUrl =>
      $composableBuilder(column: $table.fileUrl, builder: (column) => column);
}

class $$PhotoRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PhotoRowsTable,
    PhotoRow,
    $$PhotoRowsTableFilterComposer,
    $$PhotoRowsTableOrderingComposer,
    $$PhotoRowsTableAnnotationComposer,
    $$PhotoRowsTableCreateCompanionBuilder,
    $$PhotoRowsTableUpdateCompanionBuilder,
    (PhotoRow, BaseReferences<_$AppDatabase, $PhotoRowsTable, PhotoRow>),
    PhotoRow,
    PrefetchHooks Function()> {
  $$PhotoRowsTableTableManager(_$AppDatabase db, $PhotoRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> annotationId = const Value.absent(),
            Value<String> localFilePath = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isUploaded = const Value.absent(),
            Value<String?> fileUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotoRowsCompanion(
            id: id,
            annotationId: annotationId,
            localFilePath: localFilePath,
            thumbnailPath: thumbnailPath,
            createdAt: createdAt,
            isUploaded: isUploaded,
            fileUrl: fileUrl,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String annotationId,
            required String localFilePath,
            Value<String?> thumbnailPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isUploaded = const Value.absent(),
            Value<String?> fileUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotoRowsCompanion.insert(
            id: id,
            annotationId: annotationId,
            localFilePath: localFilePath,
            thumbnailPath: thumbnailPath,
            createdAt: createdAt,
            isUploaded: isUploaded,
            fileUrl: fileUrl,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PhotoRowsTable, PhotoRow>(table),
                    BaseReferences<_$AppDatabase, $PhotoRowsTable, PhotoRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PhotoRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PhotoRowsTable,
    PhotoRow,
    $$PhotoRowsTableFilterComposer,
    $$PhotoRowsTableOrderingComposer,
    $$PhotoRowsTableAnnotationComposer,
    $$PhotoRowsTableCreateCompanionBuilder,
    $$PhotoRowsTableUpdateCompanionBuilder,
    (PhotoRow, BaseReferences<_$AppDatabase, $PhotoRowsTable, PhotoRow>),
    PhotoRow,
    PrefetchHooks Function()>;
typedef $$AudioNoteRowsTableCreateCompanionBuilder = AudioNoteRowsCompanion
    Function({
  required String id,
  required String annotationId,
  required String localFilePath,
  Value<int> durationMs,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$AudioNoteRowsTableUpdateCompanionBuilder = AudioNoteRowsCompanion
    Function({
  Value<String> id,
  Value<String> annotationId,
  Value<String> localFilePath,
  Value<int> durationMs,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AudioNoteRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AudioNoteRowsTable> {
  $$AudioNoteRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get annotationId => $composableBuilder(
      column: $table.annotationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AudioNoteRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioNoteRowsTable> {
  $$AudioNoteRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get annotationId => $composableBuilder(
      column: $table.annotationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AudioNoteRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioNoteRowsTable> {
  $$AudioNoteRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get annotationId => $composableBuilder(
      column: $table.annotationId, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
      column: $table.localFilePath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AudioNoteRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AudioNoteRowsTable,
    AudioNoteRow,
    $$AudioNoteRowsTableFilterComposer,
    $$AudioNoteRowsTableOrderingComposer,
    $$AudioNoteRowsTableAnnotationComposer,
    $$AudioNoteRowsTableCreateCompanionBuilder,
    $$AudioNoteRowsTableUpdateCompanionBuilder,
    (
      AudioNoteRow,
      BaseReferences<_$AppDatabase, $AudioNoteRowsTable, AudioNoteRow>
    ),
    AudioNoteRow,
    PrefetchHooks Function()> {
  $$AudioNoteRowsTableTableManager(_$AppDatabase db, $AudioNoteRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioNoteRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioNoteRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioNoteRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> annotationId = const Value.absent(),
            Value<String> localFilePath = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AudioNoteRowsCompanion(
            id: id,
            annotationId: annotationId,
            localFilePath: localFilePath,
            durationMs: durationMs,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String annotationId,
            required String localFilePath,
            Value<int> durationMs = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AudioNoteRowsCompanion.insert(
            id: id,
            annotationId: annotationId,
            localFilePath: localFilePath,
            durationMs: durationMs,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AudioNoteRowsTable, AudioNoteRow>(table),
                    BaseReferences<_$AppDatabase, $AudioNoteRowsTable,
                        AudioNoteRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AudioNoteRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AudioNoteRowsTable,
    AudioNoteRow,
    $$AudioNoteRowsTableFilterComposer,
    $$AudioNoteRowsTableOrderingComposer,
    $$AudioNoteRowsTableAnnotationComposer,
    $$AudioNoteRowsTableCreateCompanionBuilder,
    $$AudioNoteRowsTableUpdateCompanionBuilder,
    (
      AudioNoteRow,
      BaseReferences<_$AppDatabase, $AudioNoteRowsTable, AudioNoteRow>
    ),
    AudioNoteRow,
    PrefetchHooks Function()>;
typedef $$MeasurementRowsTableCreateCompanionBuilder = MeasurementRowsCompanion
    Function({
  required String id,
  required String drawingId,
  required String type,
  required String pointsJson,
  Value<String?> annotationIdsJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$MeasurementRowsTableUpdateCompanionBuilder = MeasurementRowsCompanion
    Function({
  Value<String> id,
  Value<String> drawingId,
  Value<String> type,
  Value<String> pointsJson,
  Value<String?> annotationIdsJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$MeasurementRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MeasurementRowsTable> {
  $$MeasurementRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pointsJson => $composableBuilder(
      column: $table.pointsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get annotationIdsJson => $composableBuilder(
      column: $table.annotationIdsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MeasurementRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeasurementRowsTable> {
  $$MeasurementRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pointsJson => $composableBuilder(
      column: $table.pointsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get annotationIdsJson => $composableBuilder(
      column: $table.annotationIdsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MeasurementRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeasurementRowsTable> {
  $$MeasurementRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get drawingId =>
      $composableBuilder(column: $table.drawingId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get pointsJson => $composableBuilder(
      column: $table.pointsJson, builder: (column) => column);

  GeneratedColumn<String> get annotationIdsJson => $composableBuilder(
      column: $table.annotationIdsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MeasurementRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MeasurementRowsTable,
    MeasurementRow,
    $$MeasurementRowsTableFilterComposer,
    $$MeasurementRowsTableOrderingComposer,
    $$MeasurementRowsTableAnnotationComposer,
    $$MeasurementRowsTableCreateCompanionBuilder,
    $$MeasurementRowsTableUpdateCompanionBuilder,
    (
      MeasurementRow,
      BaseReferences<_$AppDatabase, $MeasurementRowsTable, MeasurementRow>
    ),
    MeasurementRow,
    PrefetchHooks Function()> {
  $$MeasurementRowsTableTableManager(
      _$AppDatabase db, $MeasurementRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeasurementRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeasurementRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeasurementRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> drawingId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> pointsJson = const Value.absent(),
            Value<String?> annotationIdsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MeasurementRowsCompanion(
            id: id,
            drawingId: drawingId,
            type: type,
            pointsJson: pointsJson,
            annotationIdsJson: annotationIdsJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String drawingId,
            required String type,
            required String pointsJson,
            Value<String?> annotationIdsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MeasurementRowsCompanion.insert(
            id: id,
            drawingId: drawingId,
            type: type,
            pointsJson: pointsJson,
            annotationIdsJson: annotationIdsJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MeasurementRowsTable, MeasurementRow>(table),
                    BaseReferences<_$AppDatabase, $MeasurementRowsTable,
                        MeasurementRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MeasurementRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MeasurementRowsTable,
    MeasurementRow,
    $$MeasurementRowsTableFilterComposer,
    $$MeasurementRowsTableOrderingComposer,
    $$MeasurementRowsTableAnnotationComposer,
    $$MeasurementRowsTableCreateCompanionBuilder,
    $$MeasurementRowsTableUpdateCompanionBuilder,
    (
      MeasurementRow,
      BaseReferences<_$AppDatabase, $MeasurementRowsTable, MeasurementRow>
    ),
    MeasurementRow,
    PrefetchHooks Function()>;
typedef $$DrawnObjectRowsTableCreateCompanionBuilder = DrawnObjectRowsCompanion
    Function({
  required String id,
  required String drawingId,
  required String type,
  required String pointsJson,
  Value<String?> bulgesJson,
  Value<String?> content,
  Value<double?> height,
  Value<int> color,
  Value<double> strokePx,
  Value<double> rotation,
  Value<String> layer,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$DrawnObjectRowsTableUpdateCompanionBuilder = DrawnObjectRowsCompanion
    Function({
  Value<String> id,
  Value<String> drawingId,
  Value<String> type,
  Value<String> pointsJson,
  Value<String?> bulgesJson,
  Value<String?> content,
  Value<double?> height,
  Value<int> color,
  Value<double> strokePx,
  Value<double> rotation,
  Value<String> layer,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$DrawnObjectRowsTableFilterComposer
    extends Composer<_$AppDatabase, $DrawnObjectRowsTable> {
  $$DrawnObjectRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pointsJson => $composableBuilder(
      column: $table.pointsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bulgesJson => $composableBuilder(
      column: $table.bulgesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get strokePx => $composableBuilder(
      column: $table.strokePx, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rotation => $composableBuilder(
      column: $table.rotation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layer => $composableBuilder(
      column: $table.layer, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DrawnObjectRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $DrawnObjectRowsTable> {
  $$DrawnObjectRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pointsJson => $composableBuilder(
      column: $table.pointsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bulgesJson => $composableBuilder(
      column: $table.bulgesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get strokePx => $composableBuilder(
      column: $table.strokePx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rotation => $composableBuilder(
      column: $table.rotation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layer => $composableBuilder(
      column: $table.layer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DrawnObjectRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DrawnObjectRowsTable> {
  $$DrawnObjectRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get drawingId =>
      $composableBuilder(column: $table.drawingId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get pointsJson => $composableBuilder(
      column: $table.pointsJson, builder: (column) => column);

  GeneratedColumn<String> get bulgesJson => $composableBuilder(
      column: $table.bulgesJson, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get strokePx =>
      $composableBuilder(column: $table.strokePx, builder: (column) => column);

  GeneratedColumn<double> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DrawnObjectRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DrawnObjectRowsTable,
    DrawnObjectRow,
    $$DrawnObjectRowsTableFilterComposer,
    $$DrawnObjectRowsTableOrderingComposer,
    $$DrawnObjectRowsTableAnnotationComposer,
    $$DrawnObjectRowsTableCreateCompanionBuilder,
    $$DrawnObjectRowsTableUpdateCompanionBuilder,
    (
      DrawnObjectRow,
      BaseReferences<_$AppDatabase, $DrawnObjectRowsTable, DrawnObjectRow>
    ),
    DrawnObjectRow,
    PrefetchHooks Function()> {
  $$DrawnObjectRowsTableTableManager(
      _$AppDatabase db, $DrawnObjectRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DrawnObjectRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DrawnObjectRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DrawnObjectRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> drawingId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> pointsJson = const Value.absent(),
            Value<String?> bulgesJson = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<double?> height = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<double> strokePx = const Value.absent(),
            Value<double> rotation = const Value.absent(),
            Value<String> layer = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DrawnObjectRowsCompanion(
            id: id,
            drawingId: drawingId,
            type: type,
            pointsJson: pointsJson,
            bulgesJson: bulgesJson,
            content: content,
            height: height,
            color: color,
            strokePx: strokePx,
            rotation: rotation,
            layer: layer,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String drawingId,
            required String type,
            required String pointsJson,
            Value<String?> bulgesJson = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<double?> height = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<double> strokePx = const Value.absent(),
            Value<double> rotation = const Value.absent(),
            Value<String> layer = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DrawnObjectRowsCompanion.insert(
            id: id,
            drawingId: drawingId,
            type: type,
            pointsJson: pointsJson,
            bulgesJson: bulgesJson,
            content: content,
            height: height,
            color: color,
            strokePx: strokePx,
            rotation: rotation,
            layer: layer,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DrawnObjectRowsTable, DrawnObjectRow>(table),
                    BaseReferences<_$AppDatabase, $DrawnObjectRowsTable,
                        DrawnObjectRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DrawnObjectRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DrawnObjectRowsTable,
    DrawnObjectRow,
    $$DrawnObjectRowsTableFilterComposer,
    $$DrawnObjectRowsTableOrderingComposer,
    $$DrawnObjectRowsTableAnnotationComposer,
    $$DrawnObjectRowsTableCreateCompanionBuilder,
    $$DrawnObjectRowsTableUpdateCompanionBuilder,
    (
      DrawnObjectRow,
      BaseReferences<_$AppDatabase, $DrawnObjectRowsTable, DrawnObjectRow>
    ),
    DrawnObjectRow,
    PrefetchHooks Function()>;
typedef $$HistoryEventRowsTableCreateCompanionBuilder
    = HistoryEventRowsCompanion Function({
  required String id,
  required String drawingId,
  Value<String?> annotationId,
  required String type,
  required String summary,
  Value<String?> detailsJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$HistoryEventRowsTableUpdateCompanionBuilder
    = HistoryEventRowsCompanion Function({
  Value<String> id,
  Value<String> drawingId,
  Value<String?> annotationId,
  Value<String> type,
  Value<String> summary,
  Value<String?> detailsJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$HistoryEventRowsTableFilterComposer
    extends Composer<_$AppDatabase, $HistoryEventRowsTable> {
  $$HistoryEventRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get annotationId => $composableBuilder(
      column: $table.annotationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$HistoryEventRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoryEventRowsTable> {
  $$HistoryEventRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get annotationId => $composableBuilder(
      column: $table.annotationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$HistoryEventRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoryEventRowsTable> {
  $$HistoryEventRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get drawingId =>
      $composableBuilder(column: $table.drawingId, builder: (column) => column);

  GeneratedColumn<String> get annotationId => $composableBuilder(
      column: $table.annotationId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HistoryEventRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HistoryEventRowsTable,
    HistoryEventRow,
    $$HistoryEventRowsTableFilterComposer,
    $$HistoryEventRowsTableOrderingComposer,
    $$HistoryEventRowsTableAnnotationComposer,
    $$HistoryEventRowsTableCreateCompanionBuilder,
    $$HistoryEventRowsTableUpdateCompanionBuilder,
    (
      HistoryEventRow,
      BaseReferences<_$AppDatabase, $HistoryEventRowsTable, HistoryEventRow>
    ),
    HistoryEventRow,
    PrefetchHooks Function()> {
  $$HistoryEventRowsTableTableManager(
      _$AppDatabase db, $HistoryEventRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryEventRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryEventRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryEventRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> drawingId = const Value.absent(),
            Value<String?> annotationId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> summary = const Value.absent(),
            Value<String?> detailsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HistoryEventRowsCompanion(
            id: id,
            drawingId: drawingId,
            annotationId: annotationId,
            type: type,
            summary: summary,
            detailsJson: detailsJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String drawingId,
            Value<String?> annotationId = const Value.absent(),
            required String type,
            required String summary,
            Value<String?> detailsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HistoryEventRowsCompanion.insert(
            id: id,
            drawingId: drawingId,
            annotationId: annotationId,
            type: type,
            summary: summary,
            detailsJson: detailsJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$HistoryEventRowsTable, HistoryEventRow>(table),
                    BaseReferences<_$AppDatabase, $HistoryEventRowsTable,
                        HistoryEventRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HistoryEventRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HistoryEventRowsTable,
    HistoryEventRow,
    $$HistoryEventRowsTableFilterComposer,
    $$HistoryEventRowsTableOrderingComposer,
    $$HistoryEventRowsTableAnnotationComposer,
    $$HistoryEventRowsTableCreateCompanionBuilder,
    $$HistoryEventRowsTableUpdateCompanionBuilder,
    (
      HistoryEventRow,
      BaseReferences<_$AppDatabase, $HistoryEventRowsTable, HistoryEventRow>
    ),
    HistoryEventRow,
    PrefetchHooks Function()>;
typedef $$ProjectVersionRowsTableCreateCompanionBuilder
    = ProjectVersionRowsCompanion Function({
  required String id,
  required String drawingId,
  required String label,
  required String filePath,
  Value<int> sizeBytes,
  Value<int> annotationsCount,
  Value<int> measurementsCount,
  Value<int> photosCount,
  Value<int> audioCount,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ProjectVersionRowsTableUpdateCompanionBuilder
    = ProjectVersionRowsCompanion Function({
  Value<String> id,
  Value<String> drawingId,
  Value<String> label,
  Value<String> filePath,
  Value<int> sizeBytes,
  Value<int> annotationsCount,
  Value<int> measurementsCount,
  Value<int> photosCount,
  Value<int> audioCount,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ProjectVersionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectVersionRowsTable> {
  $$ProjectVersionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get annotationsCount => $composableBuilder(
      column: $table.annotationsCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get measurementsCount => $composableBuilder(
      column: $table.measurementsCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get photosCount => $composableBuilder(
      column: $table.photosCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get audioCount => $composableBuilder(
      column: $table.audioCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ProjectVersionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectVersionRowsTable> {
  $$ProjectVersionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get drawingId => $composableBuilder(
      column: $table.drawingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get annotationsCount => $composableBuilder(
      column: $table.annotationsCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get measurementsCount => $composableBuilder(
      column: $table.measurementsCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get photosCount => $composableBuilder(
      column: $table.photosCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get audioCount => $composableBuilder(
      column: $table.audioCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ProjectVersionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectVersionRowsTable> {
  $$ProjectVersionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get drawingId =>
      $composableBuilder(column: $table.drawingId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get annotationsCount => $composableBuilder(
      column: $table.annotationsCount, builder: (column) => column);

  GeneratedColumn<int> get measurementsCount => $composableBuilder(
      column: $table.measurementsCount, builder: (column) => column);

  GeneratedColumn<int> get photosCount => $composableBuilder(
      column: $table.photosCount, builder: (column) => column);

  GeneratedColumn<int> get audioCount => $composableBuilder(
      column: $table.audioCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProjectVersionRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectVersionRowsTable,
    ProjectVersionRow,
    $$ProjectVersionRowsTableFilterComposer,
    $$ProjectVersionRowsTableOrderingComposer,
    $$ProjectVersionRowsTableAnnotationComposer,
    $$ProjectVersionRowsTableCreateCompanionBuilder,
    $$ProjectVersionRowsTableUpdateCompanionBuilder,
    (
      ProjectVersionRow,
      BaseReferences<_$AppDatabase, $ProjectVersionRowsTable, ProjectVersionRow>
    ),
    ProjectVersionRow,
    PrefetchHooks Function()> {
  $$ProjectVersionRowsTableTableManager(
      _$AppDatabase db, $ProjectVersionRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectVersionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectVersionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectVersionRowsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> drawingId = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<int> annotationsCount = const Value.absent(),
            Value<int> measurementsCount = const Value.absent(),
            Value<int> photosCount = const Value.absent(),
            Value<int> audioCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectVersionRowsCompanion(
            id: id,
            drawingId: drawingId,
            label: label,
            filePath: filePath,
            sizeBytes: sizeBytes,
            annotationsCount: annotationsCount,
            measurementsCount: measurementsCount,
            photosCount: photosCount,
            audioCount: audioCount,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String drawingId,
            required String label,
            required String filePath,
            Value<int> sizeBytes = const Value.absent(),
            Value<int> annotationsCount = const Value.absent(),
            Value<int> measurementsCount = const Value.absent(),
            Value<int> photosCount = const Value.absent(),
            Value<int> audioCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectVersionRowsCompanion.insert(
            id: id,
            drawingId: drawingId,
            label: label,
            filePath: filePath,
            sizeBytes: sizeBytes,
            annotationsCount: annotationsCount,
            measurementsCount: measurementsCount,
            photosCount: photosCount,
            audioCount: audioCount,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProjectVersionRowsTable, ProjectVersionRow>(
                        table),
                    BaseReferences<_$AppDatabase, $ProjectVersionRowsTable,
                        ProjectVersionRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProjectVersionRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectVersionRowsTable,
    ProjectVersionRow,
    $$ProjectVersionRowsTableFilterComposer,
    $$ProjectVersionRowsTableOrderingComposer,
    $$ProjectVersionRowsTableAnnotationComposer,
    $$ProjectVersionRowsTableCreateCompanionBuilder,
    $$ProjectVersionRowsTableUpdateCompanionBuilder,
    (
      ProjectVersionRow,
      BaseReferences<_$AppDatabase, $ProjectVersionRowsTable, ProjectVersionRow>
    ),
    ProjectVersionRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$DrawingsTableTableManager get drawings =>
      $$DrawingsTableTableManager(_db, _db.drawings);
  $$AnnotationRowsTableTableManager get annotationRows =>
      $$AnnotationRowsTableTableManager(_db, _db.annotationRows);
  $$PhotoRowsTableTableManager get photoRows =>
      $$PhotoRowsTableTableManager(_db, _db.photoRows);
  $$AudioNoteRowsTableTableManager get audioNoteRows =>
      $$AudioNoteRowsTableTableManager(_db, _db.audioNoteRows);
  $$MeasurementRowsTableTableManager get measurementRows =>
      $$MeasurementRowsTableTableManager(_db, _db.measurementRows);
  $$DrawnObjectRowsTableTableManager get drawnObjectRows =>
      $$DrawnObjectRowsTableTableManager(_db, _db.drawnObjectRows);
  $$HistoryEventRowsTableTableManager get historyEventRows =>
      $$HistoryEventRowsTableTableManager(_db, _db.historyEventRows);
  $$ProjectVersionRowsTableTableManager get projectVersionRows =>
      $$ProjectVersionRowsTableTableManager(_db, _db.projectVersionRows);
}
