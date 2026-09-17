// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $SubjectsTable extends Subjects with TableInfo<$SubjectsTable, Subject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameCnMeta = const VerificationMeta('nameCn');
  @override
  late final GeneratedColumn<String> nameCn = GeneratedColumn<String>(
    'name_cn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, nameCn, summary];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_cn')) {
      context.handle(
        _nameCnMeta,
        nameCn.isAcceptableOrUnknown(data['name_cn']!, _nameCnMeta),
      );
    } else if (isInserting) {
      context.missing(_nameCnMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameCn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_cn'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
    );
  }

  @override
  $SubjectsTable createAlias(String alias) {
    return $SubjectsTable(attachedDatabase, alias);
  }
}

class Subject extends DataClass implements Insertable<Subject> {
  final int id;
  final String name;
  final String nameCn;
  final String? summary;
  const Subject({
    required this.id,
    required this.name,
    required this.nameCn,
    this.summary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['name_cn'] = Variable<String>(nameCn);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      id: Value(id),
      name: Value(name),
      nameCn: Value(nameCn),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
    );
  }

  factory Subject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subject(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameCn: serializer.fromJson<String>(json['nameCn']),
      summary: serializer.fromJson<String?>(json['summary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'nameCn': serializer.toJson<String>(nameCn),
      'summary': serializer.toJson<String?>(summary),
    };
  }

  Subject copyWith({
    int? id,
    String? name,
    String? nameCn,
    Value<String?> summary = const Value.absent(),
  }) => Subject(
    id: id ?? this.id,
    name: name ?? this.name,
    nameCn: nameCn ?? this.nameCn,
    summary: summary.present ? summary.value : this.summary,
  );
  Subject copyWithCompanion(SubjectsCompanion data) {
    return Subject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameCn: data.nameCn.present ? data.nameCn.value : this.nameCn,
      summary: data.summary.present ? data.summary.value : this.summary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('summary: $summary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, nameCn, summary);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subject &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameCn == this.nameCn &&
          other.summary == this.summary);
}

class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> nameCn;
  final Value<String?> summary;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameCn = const Value.absent(),
    this.summary = const Value.absent(),
  });
  SubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String nameCn,
    this.summary = const Value.absent(),
  }) : name = Value(name),
       nameCn = Value(nameCn);
  static Insertable<Subject> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? nameCn,
    Expression<String>? summary,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameCn != null) 'name_cn': nameCn,
      if (summary != null) 'summary': summary,
    });
  }

  SubjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? nameCn,
    Value<String?>? summary,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameCn: nameCn ?? this.nameCn,
      summary: summary ?? this.summary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameCn.present) {
      map['name_cn'] = Variable<String>(nameCn.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('summary: $summary')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, Episode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subjects (id)',
    ),
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<String> sort = GeneratedColumn<String>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, subjectId, sort, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Episode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    } else if (isInserting) {
      context.missing(_sortMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Episode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Episode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class Episode extends DataClass implements Insertable<Episode> {
  final int id;
  final int subjectId;
  final String sort;
  final String name;
  const Episode({
    required this.id,
    required this.subjectId,
    required this.sort,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['sort'] = Variable<String>(sort);
    map['name'] = Variable<String>(name);
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      sort: Value(sort),
      name: Value(name),
    );
  }

  factory Episode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Episode(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      sort: serializer.fromJson<String>(json['sort']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'sort': serializer.toJson<String>(sort),
      'name': serializer.toJson<String>(name),
    };
  }

  Episode copyWith({int? id, int? subjectId, String? sort, String? name}) =>
      Episode(
        id: id ?? this.id,
        subjectId: subjectId ?? this.subjectId,
        sort: sort ?? this.sort,
        name: name ?? this.name,
      );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      sort: data.sort.present ? data.sort.value : this.sort,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('sort: $sort, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, subjectId, sort, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.sort == this.sort &&
          other.name == this.name);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> sort;
  final Value<String> name;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.sort = const Value.absent(),
    this.name = const Value.absent(),
  });
  EpisodesCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String sort,
    required String name,
  }) : subjectId = Value(subjectId),
       sort = Value(sort),
       name = Value(name);
  static Insertable<Episode> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? sort,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (sort != null) 'sort': sort,
      if (name != null) 'name': name,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? sort,
    Value<String>? name,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      sort: sort ?? this.sort,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (sort.present) {
      map['sort'] = Variable<String>(sort.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('sort: $sort, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $SubjectCollectionsTable extends SubjectCollections
    with TableInfo<$SubjectCollectionsTable, SubjectCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subjects (id)',
    ),
  );
  static const VerificationMeta _collectionTypeMeta = const VerificationMeta(
    'collectionType',
  );
  @override
  late final GeneratedColumn<String> collectionType = GeneratedColumn<String>(
    'collection_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selfRatingScoreMeta = const VerificationMeta(
    'selfRatingScore',
  );
  @override
  late final GeneratedColumn<int> selfRatingScore = GeneratedColumn<int>(
    'self_rating_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selfRatingCommentMeta = const VerificationMeta(
    'selfRatingComment',
  );
  @override
  late final GeneratedColumn<String> selfRatingComment =
      GeneratedColumn<String>(
        'self_rating_comment',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isPrivateMeta = const VerificationMeta(
    'isPrivate',
  );
  @override
  late final GeneratedColumn<bool> isPrivate = GeneratedColumn<bool>(
    'is_private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    subjectId,
    collectionType,
    selfRatingScore,
    selfRatingComment,
    isPrivate,
    dirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subject_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectCollection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('collection_type')) {
      context.handle(
        _collectionTypeMeta,
        collectionType.isAcceptableOrUnknown(
          data['collection_type']!,
          _collectionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionTypeMeta);
    }
    if (data.containsKey('self_rating_score')) {
      context.handle(
        _selfRatingScoreMeta,
        selfRatingScore.isAcceptableOrUnknown(
          data['self_rating_score']!,
          _selfRatingScoreMeta,
        ),
      );
    }
    if (data.containsKey('self_rating_comment')) {
      context.handle(
        _selfRatingCommentMeta,
        selfRatingComment.isAcceptableOrUnknown(
          data['self_rating_comment']!,
          _selfRatingCommentMeta,
        ),
      );
    }
    if (data.containsKey('is_private')) {
      context.handle(
        _isPrivateMeta,
        isPrivate.isAcceptableOrUnknown(data['is_private']!, _isPrivateMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectId};
  @override
  SubjectCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectCollection(
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      collectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_type'],
      )!,
      selfRatingScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}self_rating_score'],
      ),
      selfRatingComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}self_rating_comment'],
      ),
      isPrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_private'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $SubjectCollectionsTable createAlias(String alias) {
    return $SubjectCollectionsTable(attachedDatabase, alias);
  }
}

class SubjectCollection extends DataClass
    implements Insertable<SubjectCollection> {
  final int subjectId;
  final String collectionType;
  final int? selfRatingScore;
  final String? selfRatingComment;
  final bool isPrivate;
  final bool dirty;
  final DateTime? syncedAt;
  const SubjectCollection({
    required this.subjectId,
    required this.collectionType,
    this.selfRatingScore,
    this.selfRatingComment,
    required this.isPrivate,
    required this.dirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subject_id'] = Variable<int>(subjectId);
    map['collection_type'] = Variable<String>(collectionType);
    if (!nullToAbsent || selfRatingScore != null) {
      map['self_rating_score'] = Variable<int>(selfRatingScore);
    }
    if (!nullToAbsent || selfRatingComment != null) {
      map['self_rating_comment'] = Variable<String>(selfRatingComment);
    }
    map['is_private'] = Variable<bool>(isPrivate);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  SubjectCollectionsCompanion toCompanion(bool nullToAbsent) {
    return SubjectCollectionsCompanion(
      subjectId: Value(subjectId),
      collectionType: Value(collectionType),
      selfRatingScore: selfRatingScore == null && nullToAbsent
          ? const Value.absent()
          : Value(selfRatingScore),
      selfRatingComment: selfRatingComment == null && nullToAbsent
          ? const Value.absent()
          : Value(selfRatingComment),
      isPrivate: Value(isPrivate),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory SubjectCollection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectCollection(
      subjectId: serializer.fromJson<int>(json['subjectId']),
      collectionType: serializer.fromJson<String>(json['collectionType']),
      selfRatingScore: serializer.fromJson<int?>(json['selfRatingScore']),
      selfRatingComment: serializer.fromJson<String?>(
        json['selfRatingComment'],
      ),
      isPrivate: serializer.fromJson<bool>(json['isPrivate']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectId': serializer.toJson<int>(subjectId),
      'collectionType': serializer.toJson<String>(collectionType),
      'selfRatingScore': serializer.toJson<int?>(selfRatingScore),
      'selfRatingComment': serializer.toJson<String?>(selfRatingComment),
      'isPrivate': serializer.toJson<bool>(isPrivate),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  SubjectCollection copyWith({
    int? subjectId,
    String? collectionType,
    Value<int?> selfRatingScore = const Value.absent(),
    Value<String?> selfRatingComment = const Value.absent(),
    bool? isPrivate,
    bool? dirty,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => SubjectCollection(
    subjectId: subjectId ?? this.subjectId,
    collectionType: collectionType ?? this.collectionType,
    selfRatingScore: selfRatingScore.present
        ? selfRatingScore.value
        : this.selfRatingScore,
    selfRatingComment: selfRatingComment.present
        ? selfRatingComment.value
        : this.selfRatingComment,
    isPrivate: isPrivate ?? this.isPrivate,
    dirty: dirty ?? this.dirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  SubjectCollection copyWithCompanion(SubjectCollectionsCompanion data) {
    return SubjectCollection(
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      selfRatingScore: data.selfRatingScore.present
          ? data.selfRatingScore.value
          : this.selfRatingScore,
      selfRatingComment: data.selfRatingComment.present
          ? data.selfRatingComment.value
          : this.selfRatingComment,
      isPrivate: data.isPrivate.present ? data.isPrivate.value : this.isPrivate,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectCollection(')
          ..write('subjectId: $subjectId, ')
          ..write('collectionType: $collectionType, ')
          ..write('selfRatingScore: $selfRatingScore, ')
          ..write('selfRatingComment: $selfRatingComment, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    subjectId,
    collectionType,
    selfRatingScore,
    selfRatingComment,
    isPrivate,
    dirty,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectCollection &&
          other.subjectId == this.subjectId &&
          other.collectionType == this.collectionType &&
          other.selfRatingScore == this.selfRatingScore &&
          other.selfRatingComment == this.selfRatingComment &&
          other.isPrivate == this.isPrivate &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt);
}

class SubjectCollectionsCompanion extends UpdateCompanion<SubjectCollection> {
  final Value<int> subjectId;
  final Value<String> collectionType;
  final Value<int?> selfRatingScore;
  final Value<String?> selfRatingComment;
  final Value<bool> isPrivate;
  final Value<bool> dirty;
  final Value<DateTime?> syncedAt;
  const SubjectCollectionsCompanion({
    this.subjectId = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.selfRatingScore = const Value.absent(),
    this.selfRatingComment = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  SubjectCollectionsCompanion.insert({
    this.subjectId = const Value.absent(),
    required String collectionType,
    this.selfRatingScore = const Value.absent(),
    this.selfRatingComment = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : collectionType = Value(collectionType);
  static Insertable<SubjectCollection> custom({
    Expression<int>? subjectId,
    Expression<String>? collectionType,
    Expression<int>? selfRatingScore,
    Expression<String>? selfRatingComment,
    Expression<bool>? isPrivate,
    Expression<bool>? dirty,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (subjectId != null) 'subject_id': subjectId,
      if (collectionType != null) 'collection_type': collectionType,
      if (selfRatingScore != null) 'self_rating_score': selfRatingScore,
      if (selfRatingComment != null) 'self_rating_comment': selfRatingComment,
      if (isPrivate != null) 'is_private': isPrivate,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  SubjectCollectionsCompanion copyWith({
    Value<int>? subjectId,
    Value<String>? collectionType,
    Value<int?>? selfRatingScore,
    Value<String?>? selfRatingComment,
    Value<bool>? isPrivate,
    Value<bool>? dirty,
    Value<DateTime?>? syncedAt,
  }) {
    return SubjectCollectionsCompanion(
      subjectId: subjectId ?? this.subjectId,
      collectionType: collectionType ?? this.collectionType,
      selfRatingScore: selfRatingScore ?? this.selfRatingScore,
      selfRatingComment: selfRatingComment ?? this.selfRatingComment,
      isPrivate: isPrivate ?? this.isPrivate,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (collectionType.present) {
      map['collection_type'] = Variable<String>(collectionType.value);
    }
    if (selfRatingScore.present) {
      map['self_rating_score'] = Variable<int>(selfRatingScore.value);
    }
    if (selfRatingComment.present) {
      map['self_rating_comment'] = Variable<String>(selfRatingComment.value);
    }
    if (isPrivate.present) {
      map['is_private'] = Variable<bool>(isPrivate.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectCollectionsCompanion(')
          ..write('subjectId: $subjectId, ')
          ..write('collectionType: $collectionType, ')
          ..write('selfRatingScore: $selfRatingScore, ')
          ..write('selfRatingComment: $selfRatingComment, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, query, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_searchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryData extends DataClass
    implements Insertable<SearchHistoryData> {
  final int id;
  final String query;
  final DateTime searchedAt;
  const SearchHistoryData({
    required this.id,
    required this.query,
    required this.searchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query'] = Variable<String>(query);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      id: Value(id),
      query: Value(query),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryData(
      id: serializer.fromJson<int>(json['id']),
      query: serializer.fromJson<String>(json['query']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'query': serializer.toJson<String>(query),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchHistoryData copyWith({int? id, String? query, DateTime? searchedAt}) =>
      SearchHistoryData(
        id: id ?? this.id,
        query: query ?? this.query,
        searchedAt: searchedAt ?? this.searchedAt,
      );
  SearchHistoryData copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryData(
      id: data.id.present ? data.id.value : this.id,
      query: data.query.present ? data.query.value : this.query,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryData(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, query, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryData &&
          other.id == this.id &&
          other.query == this.query &&
          other.searchedAt == this.searchedAt);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryData> {
  final Value<int> id;
  final Value<String> query;
  final Value<DateTime> searchedAt;
  const SearchHistoryCompanion({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String query,
    required DateTime searchedAt,
  }) : query = Value(query),
       searchedAt = Value(searchedAt);
  static Insertable<SearchHistoryData> custom({
    Expression<int>? id,
    Expression<String>? query,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (query != null) 'query': query,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? query,
    Value<DateTime>? searchedAt,
  }) {
    return SearchHistoryCompanion(
      id: id ?? this.id,
      query: query ?? this.query,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

class $SubjectImageCacheTable extends SubjectImageCache
    with TableInfo<$SubjectImageCacheTable, SubjectImageCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectImageCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [subjectId, imageUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subject_image_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectImageCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_imageUrlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectId};
  @override
  SubjectImageCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectImageCacheData(
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      )!,
    );
  }

  @override
  $SubjectImageCacheTable createAlias(String alias) {
    return $SubjectImageCacheTable(attachedDatabase, alias);
  }
}

class SubjectImageCacheData extends DataClass
    implements Insertable<SubjectImageCacheData> {
  final int subjectId;
  final String imageUrl;
  const SubjectImageCacheData({
    required this.subjectId,
    required this.imageUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subject_id'] = Variable<int>(subjectId);
    map['image_url'] = Variable<String>(imageUrl);
    return map;
  }

  SubjectImageCacheCompanion toCompanion(bool nullToAbsent) {
    return SubjectImageCacheCompanion(
      subjectId: Value(subjectId),
      imageUrl: Value(imageUrl),
    );
  }

  factory SubjectImageCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectImageCacheData(
      subjectId: serializer.fromJson<int>(json['subjectId']),
      imageUrl: serializer.fromJson<String>(json['imageUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectId': serializer.toJson<int>(subjectId),
      'imageUrl': serializer.toJson<String>(imageUrl),
    };
  }

  SubjectImageCacheData copyWith({int? subjectId, String? imageUrl}) =>
      SubjectImageCacheData(
        subjectId: subjectId ?? this.subjectId,
        imageUrl: imageUrl ?? this.imageUrl,
      );
  SubjectImageCacheData copyWithCompanion(SubjectImageCacheCompanion data) {
    return SubjectImageCacheData(
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectImageCacheData(')
          ..write('subjectId: $subjectId, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(subjectId, imageUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectImageCacheData &&
          other.subjectId == this.subjectId &&
          other.imageUrl == this.imageUrl);
}

class SubjectImageCacheCompanion
    extends UpdateCompanion<SubjectImageCacheData> {
  final Value<int> subjectId;
  final Value<String> imageUrl;
  const SubjectImageCacheCompanion({
    this.subjectId = const Value.absent(),
    this.imageUrl = const Value.absent(),
  });
  SubjectImageCacheCompanion.insert({
    this.subjectId = const Value.absent(),
    required String imageUrl,
  }) : imageUrl = Value(imageUrl);
  static Insertable<SubjectImageCacheData> custom({
    Expression<int>? subjectId,
    Expression<String>? imageUrl,
  }) {
    return RawValuesInsertable({
      if (subjectId != null) 'subject_id': subjectId,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  SubjectImageCacheCompanion copyWith({
    Value<int>? subjectId,
    Value<String>? imageUrl,
  }) {
    return SubjectImageCacheCompanion(
      subjectId: subjectId ?? this.subjectId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectImageCacheCompanion(')
          ..write('subjectId: $subjectId, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }
}

class $MikanSubjectMappingsTable extends MikanSubjectMappings
    with TableInfo<$MikanSubjectMappingsTable, MikanSubjectMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MikanSubjectMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mikanBangumiIdMeta = const VerificationMeta(
    'mikanBangumiId',
  );
  @override
  late final GeneratedColumn<int> mikanBangumiId = GeneratedColumn<int>(
    'mikan_bangumi_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [subjectId, mikanBangumiId, resolvedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mikan_subject_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<MikanSubjectMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('mikan_bangumi_id')) {
      context.handle(
        _mikanBangumiIdMeta,
        mikanBangumiId.isAcceptableOrUnknown(
          data['mikan_bangumi_id']!,
          _mikanBangumiIdMeta,
        ),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_resolvedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectId};
  @override
  MikanSubjectMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MikanSubjectMapping(
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      mikanBangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mikan_bangumi_id'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      )!,
    );
  }

  @override
  $MikanSubjectMappingsTable createAlias(String alias) {
    return $MikanSubjectMappingsTable(attachedDatabase, alias);
  }
}

class MikanSubjectMapping extends DataClass
    implements Insertable<MikanSubjectMapping> {
  final int subjectId;
  final int? mikanBangumiId;
  final DateTime resolvedAt;
  const MikanSubjectMapping({
    required this.subjectId,
    this.mikanBangumiId,
    required this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subject_id'] = Variable<int>(subjectId);
    if (!nullToAbsent || mikanBangumiId != null) {
      map['mikan_bangumi_id'] = Variable<int>(mikanBangumiId);
    }
    map['resolved_at'] = Variable<DateTime>(resolvedAt);
    return map;
  }

  MikanSubjectMappingsCompanion toCompanion(bool nullToAbsent) {
    return MikanSubjectMappingsCompanion(
      subjectId: Value(subjectId),
      mikanBangumiId: mikanBangumiId == null && nullToAbsent
          ? const Value.absent()
          : Value(mikanBangumiId),
      resolvedAt: Value(resolvedAt),
    );
  }

  factory MikanSubjectMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MikanSubjectMapping(
      subjectId: serializer.fromJson<int>(json['subjectId']),
      mikanBangumiId: serializer.fromJson<int?>(json['mikanBangumiId']),
      resolvedAt: serializer.fromJson<DateTime>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectId': serializer.toJson<int>(subjectId),
      'mikanBangumiId': serializer.toJson<int?>(mikanBangumiId),
      'resolvedAt': serializer.toJson<DateTime>(resolvedAt),
    };
  }

  MikanSubjectMapping copyWith({
    int? subjectId,
    Value<int?> mikanBangumiId = const Value.absent(),
    DateTime? resolvedAt,
  }) => MikanSubjectMapping(
    subjectId: subjectId ?? this.subjectId,
    mikanBangumiId: mikanBangumiId.present
        ? mikanBangumiId.value
        : this.mikanBangumiId,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );
  MikanSubjectMapping copyWithCompanion(MikanSubjectMappingsCompanion data) {
    return MikanSubjectMapping(
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      mikanBangumiId: data.mikanBangumiId.present
          ? data.mikanBangumiId.value
          : this.mikanBangumiId,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MikanSubjectMapping(')
          ..write('subjectId: $subjectId, ')
          ..write('mikanBangumiId: $mikanBangumiId, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(subjectId, mikanBangumiId, resolvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MikanSubjectMapping &&
          other.subjectId == this.subjectId &&
          other.mikanBangumiId == this.mikanBangumiId &&
          other.resolvedAt == this.resolvedAt);
}

class MikanSubjectMappingsCompanion
    extends UpdateCompanion<MikanSubjectMapping> {
  final Value<int> subjectId;
  final Value<int?> mikanBangumiId;
  final Value<DateTime> resolvedAt;
  const MikanSubjectMappingsCompanion({
    this.subjectId = const Value.absent(),
    this.mikanBangumiId = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  MikanSubjectMappingsCompanion.insert({
    this.subjectId = const Value.absent(),
    this.mikanBangumiId = const Value.absent(),
    required DateTime resolvedAt,
  }) : resolvedAt = Value(resolvedAt);
  static Insertable<MikanSubjectMapping> custom({
    Expression<int>? subjectId,
    Expression<int>? mikanBangumiId,
    Expression<DateTime>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (subjectId != null) 'subject_id': subjectId,
      if (mikanBangumiId != null) 'mikan_bangumi_id': mikanBangumiId,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  MikanSubjectMappingsCompanion copyWith({
    Value<int>? subjectId,
    Value<int?>? mikanBangumiId,
    Value<DateTime>? resolvedAt,
  }) {
    return MikanSubjectMappingsCompanion(
      subjectId: subjectId ?? this.subjectId,
      mikanBangumiId: mikanBangumiId ?? this.mikanBangumiId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (mikanBangumiId.present) {
      map['mikan_bangumi_id'] = Variable<int>(mikanBangumiId.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MikanSubjectMappingsCompanion(')
          ..write('subjectId: $subjectId, ')
          ..write('mikanBangumiId: $mikanBangumiId, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadedEpisodesTable extends DownloadedEpisodes
    with TableInfo<$DownloadedEpisodesTable, DownloadedEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadedEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeKeyMeta = const VerificationMeta(
    'episodeKey',
  );
  @override
  late final GeneratedColumn<String> episodeKey = GeneratedColumn<String>(
    'episode_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _subjectNameMeta = const VerificationMeta(
    'subjectName',
  );
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
    'subject_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeLabelMeta = const VerificationMeta(
    'episodeLabel',
  );
  @override
  late final GeneratedColumn<String> episodeLabel = GeneratedColumn<String>(
    'episode_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receivedBytesMeta = const VerificationMeta(
    'receivedBytes',
  );
  @override
  late final GeneratedColumn<int> receivedBytes = GeneratedColumn<int>(
    'received_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedSegmentsMeta =
      const VerificationMeta('downloadedSegments');
  @override
  late final GeneratedColumn<int> downloadedSegments = GeneratedColumn<int>(
    'downloaded_segments',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalSegmentsMeta = const VerificationMeta(
    'totalSegments',
  );
  @override
  late final GeneratedColumn<int> totalSegments = GeneratedColumn<int>(
    'total_segments',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastProgressAtMeta = const VerificationMeta(
    'lastProgressAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastProgressAt =
      GeneratedColumn<DateTime>(
        'last_progress_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _episodeDirMeta = const VerificationMeta(
    'episodeDir',
  );
  @override
  late final GeneratedColumn<String> episodeDir = GeneratedColumn<String>(
    'episode_dir',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    subjectId,
    episodeKey,
    subjectName,
    episodeLabel,
    localPath,
    format,
    fileSizeBytes,
    status,
    errorMessage,
    createdAt,
    completedAt,
    receivedBytes,
    totalBytes,
    downloadedSegments,
    totalSegments,
    lastProgressAt,
    episodeDir,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloaded_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadedEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('episode_key')) {
      context.handle(
        _episodeKeyMeta,
        episodeKey.isAcceptableOrUnknown(data['episode_key']!, _episodeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeKeyMeta);
    }
    if (data.containsKey('subject_name')) {
      context.handle(
        _subjectNameMeta,
        subjectName.isAcceptableOrUnknown(
          data['subject_name']!,
          _subjectNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectNameMeta);
    }
    if (data.containsKey('episode_label')) {
      context.handle(
        _episodeLabelMeta,
        episodeLabel.isAcceptableOrUnknown(
          data['episode_label']!,
          _episodeLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeLabelMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('received_bytes')) {
      context.handle(
        _receivedBytesMeta,
        receivedBytes.isAcceptableOrUnknown(
          data['received_bytes']!,
          _receivedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('downloaded_segments')) {
      context.handle(
        _downloadedSegmentsMeta,
        downloadedSegments.isAcceptableOrUnknown(
          data['downloaded_segments']!,
          _downloadedSegmentsMeta,
        ),
      );
    }
    if (data.containsKey('total_segments')) {
      context.handle(
        _totalSegmentsMeta,
        totalSegments.isAcceptableOrUnknown(
          data['total_segments']!,
          _totalSegmentsMeta,
        ),
      );
    }
    if (data.containsKey('last_progress_at')) {
      context.handle(
        _lastProgressAtMeta,
        lastProgressAt.isAcceptableOrUnknown(
          data['last_progress_at']!,
          _lastProgressAtMeta,
        ),
      );
    }
    if (data.containsKey('episode_dir')) {
      context.handle(
        _episodeDirMeta,
        episodeDir.isAcceptableOrUnknown(data['episode_dir']!, _episodeDirMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadedEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadedEpisode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      episodeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_key'],
      )!,
      subjectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_name'],
      )!,
      episodeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_label'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      receivedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      downloadedSegments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_segments'],
      ),
      totalSegments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_segments'],
      ),
      lastProgressAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_progress_at'],
      ),
      episodeDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_dir'],
      ),
    );
  }

  @override
  $DownloadedEpisodesTable createAlias(String alias) {
    return $DownloadedEpisodesTable(attachedDatabase, alias);
  }
}

class DownloadedEpisode extends DataClass
    implements Insertable<DownloadedEpisode> {
  final int id;
  final String sourceId;
  final int subjectId;
  final String episodeKey;
  final String subjectName;
  final String episodeLabel;
  final String localPath;
  final String format;
  final int? fileSizeBytes;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// mp4 downloads: bytes received so far. HLS downloads use
  /// [downloadedSegments] instead (segment-level progress; mp4-level byte
  /// counts for HLS would require re-parsing partial .ts files). Defaults
  /// to 0 so existing rows read back as "no progress" rather than null.
  final int receivedBytes;

  /// mp4 downloads: total size from the `Content-Length` header, once
  /// known. Null for HLS (no single Content-Length) and for mp4 downloads
  /// before the response headers arrive.
  final int? totalBytes;

  /// HLS downloads: segments downloaded so far.
  final int? downloadedSegments;

  /// HLS downloads: total segment count, counted from the manifest before
  /// downloading starts.
  final int? totalSegments;

  /// Last time [receivedBytes]/[downloadedSegments] increased. Used by the
  /// worker's stall detection (see `DownloadWorker`); not shown directly in
  /// the UI.
  final DateTime? lastProgressAt;

  /// The directory this episode's file(s) live in, written once by
  /// `DownloadWorker` when it creates the directory. Deletion always uses
  /// this column, never [localPath] (which is a *file* path for completed
  /// downloads but historically was the *directory* path for
  /// downloading/failed ones — see the design spec's bug #7). Null on rows
  /// created before this migration; deletion falls back to the pre-v5
  /// heuristic for those (see `DownloadedEpisodeRepository.deleteWithFiles`).
  final String? episodeDir;
  const DownloadedEpisode({
    required this.id,
    required this.sourceId,
    required this.subjectId,
    required this.episodeKey,
    required this.subjectName,
    required this.episodeLabel,
    required this.localPath,
    required this.format,
    this.fileSizeBytes,
    required this.status,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    required this.receivedBytes,
    this.totalBytes,
    this.downloadedSegments,
    this.totalSegments,
    this.lastProgressAt,
    this.episodeDir,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['subject_id'] = Variable<int>(subjectId);
    map['episode_key'] = Variable<String>(episodeKey);
    map['subject_name'] = Variable<String>(subjectName);
    map['episode_label'] = Variable<String>(episodeLabel);
    map['local_path'] = Variable<String>(localPath);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['received_bytes'] = Variable<int>(receivedBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || downloadedSegments != null) {
      map['downloaded_segments'] = Variable<int>(downloadedSegments);
    }
    if (!nullToAbsent || totalSegments != null) {
      map['total_segments'] = Variable<int>(totalSegments);
    }
    if (!nullToAbsent || lastProgressAt != null) {
      map['last_progress_at'] = Variable<DateTime>(lastProgressAt);
    }
    if (!nullToAbsent || episodeDir != null) {
      map['episode_dir'] = Variable<String>(episodeDir);
    }
    return map;
  }

  DownloadedEpisodesCompanion toCompanion(bool nullToAbsent) {
    return DownloadedEpisodesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      subjectId: Value(subjectId),
      episodeKey: Value(episodeKey),
      subjectName: Value(subjectName),
      episodeLabel: Value(episodeLabel),
      localPath: Value(localPath),
      format: Value(format),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      receivedBytes: Value(receivedBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      downloadedSegments: downloadedSegments == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedSegments),
      totalSegments: totalSegments == null && nullToAbsent
          ? const Value.absent()
          : Value(totalSegments),
      lastProgressAt: lastProgressAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastProgressAt),
      episodeDir: episodeDir == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeDir),
    );
  }

  factory DownloadedEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadedEpisode(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      episodeKey: serializer.fromJson<String>(json['episodeKey']),
      subjectName: serializer.fromJson<String>(json['subjectName']),
      episodeLabel: serializer.fromJson<String>(json['episodeLabel']),
      localPath: serializer.fromJson<String>(json['localPath']),
      format: serializer.fromJson<String>(json['format']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      receivedBytes: serializer.fromJson<int>(json['receivedBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      downloadedSegments: serializer.fromJson<int?>(json['downloadedSegments']),
      totalSegments: serializer.fromJson<int?>(json['totalSegments']),
      lastProgressAt: serializer.fromJson<DateTime?>(json['lastProgressAt']),
      episodeDir: serializer.fromJson<String?>(json['episodeDir']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'subjectId': serializer.toJson<int>(subjectId),
      'episodeKey': serializer.toJson<String>(episodeKey),
      'subjectName': serializer.toJson<String>(subjectName),
      'episodeLabel': serializer.toJson<String>(episodeLabel),
      'localPath': serializer.toJson<String>(localPath),
      'format': serializer.toJson<String>(format),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'receivedBytes': serializer.toJson<int>(receivedBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'downloadedSegments': serializer.toJson<int?>(downloadedSegments),
      'totalSegments': serializer.toJson<int?>(totalSegments),
      'lastProgressAt': serializer.toJson<DateTime?>(lastProgressAt),
      'episodeDir': serializer.toJson<String?>(episodeDir),
    };
  }

  DownloadedEpisode copyWith({
    int? id,
    String? sourceId,
    int? subjectId,
    String? episodeKey,
    String? subjectName,
    String? episodeLabel,
    String? localPath,
    String? format,
    Value<int?> fileSizeBytes = const Value.absent(),
    String? status,
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
    int? receivedBytes,
    Value<int?> totalBytes = const Value.absent(),
    Value<int?> downloadedSegments = const Value.absent(),
    Value<int?> totalSegments = const Value.absent(),
    Value<DateTime?> lastProgressAt = const Value.absent(),
    Value<String?> episodeDir = const Value.absent(),
  }) => DownloadedEpisode(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    subjectId: subjectId ?? this.subjectId,
    episodeKey: episodeKey ?? this.episodeKey,
    subjectName: subjectName ?? this.subjectName,
    episodeLabel: episodeLabel ?? this.episodeLabel,
    localPath: localPath ?? this.localPath,
    format: format ?? this.format,
    fileSizeBytes: fileSizeBytes.present
        ? fileSizeBytes.value
        : this.fileSizeBytes,
    status: status ?? this.status,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    downloadedSegments: downloadedSegments.present
        ? downloadedSegments.value
        : this.downloadedSegments,
    totalSegments: totalSegments.present
        ? totalSegments.value
        : this.totalSegments,
    lastProgressAt: lastProgressAt.present
        ? lastProgressAt.value
        : this.lastProgressAt,
    episodeDir: episodeDir.present ? episodeDir.value : this.episodeDir,
  );
  DownloadedEpisode copyWithCompanion(DownloadedEpisodesCompanion data) {
    return DownloadedEpisode(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      episodeKey: data.episodeKey.present
          ? data.episodeKey.value
          : this.episodeKey,
      subjectName: data.subjectName.present
          ? data.subjectName.value
          : this.subjectName,
      episodeLabel: data.episodeLabel.present
          ? data.episodeLabel.value
          : this.episodeLabel,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      format: data.format.present ? data.format.value : this.format,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      receivedBytes: data.receivedBytes.present
          ? data.receivedBytes.value
          : this.receivedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadedSegments: data.downloadedSegments.present
          ? data.downloadedSegments.value
          : this.downloadedSegments,
      totalSegments: data.totalSegments.present
          ? data.totalSegments.value
          : this.totalSegments,
      lastProgressAt: data.lastProgressAt.present
          ? data.lastProgressAt.value
          : this.lastProgressAt,
      episodeDir: data.episodeDir.present
          ? data.episodeDir.value
          : this.episodeDir,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedEpisode(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodeKey: $episodeKey, ')
          ..write('subjectName: $subjectName, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('localPath: $localPath, ')
          ..write('format: $format, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedSegments: $downloadedSegments, ')
          ..write('totalSegments: $totalSegments, ')
          ..write('lastProgressAt: $lastProgressAt, ')
          ..write('episodeDir: $episodeDir')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    subjectId,
    episodeKey,
    subjectName,
    episodeLabel,
    localPath,
    format,
    fileSizeBytes,
    status,
    errorMessage,
    createdAt,
    completedAt,
    receivedBytes,
    totalBytes,
    downloadedSegments,
    totalSegments,
    lastProgressAt,
    episodeDir,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadedEpisode &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.subjectId == this.subjectId &&
          other.episodeKey == this.episodeKey &&
          other.subjectName == this.subjectName &&
          other.episodeLabel == this.episodeLabel &&
          other.localPath == this.localPath &&
          other.format == this.format &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.receivedBytes == this.receivedBytes &&
          other.totalBytes == this.totalBytes &&
          other.downloadedSegments == this.downloadedSegments &&
          other.totalSegments == this.totalSegments &&
          other.lastProgressAt == this.lastProgressAt &&
          other.episodeDir == this.episodeDir);
}

class DownloadedEpisodesCompanion extends UpdateCompanion<DownloadedEpisode> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<int> subjectId;
  final Value<String> episodeKey;
  final Value<String> subjectName;
  final Value<String> episodeLabel;
  final Value<String> localPath;
  final Value<String> format;
  final Value<int?> fileSizeBytes;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> receivedBytes;
  final Value<int?> totalBytes;
  final Value<int?> downloadedSegments;
  final Value<int?> totalSegments;
  final Value<DateTime?> lastProgressAt;
  final Value<String?> episodeDir;
  const DownloadedEpisodesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.episodeKey = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.episodeLabel = const Value.absent(),
    this.localPath = const Value.absent(),
    this.format = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.receivedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedSegments = const Value.absent(),
    this.totalSegments = const Value.absent(),
    this.lastProgressAt = const Value.absent(),
    this.episodeDir = const Value.absent(),
  });
  DownloadedEpisodesCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required int subjectId,
    required String episodeKey,
    required String subjectName,
    required String episodeLabel,
    required String localPath,
    required String format,
    this.fileSizeBytes = const Value.absent(),
    required String status,
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.receivedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedSegments = const Value.absent(),
    this.totalSegments = const Value.absent(),
    this.lastProgressAt = const Value.absent(),
    this.episodeDir = const Value.absent(),
  }) : sourceId = Value(sourceId),
       subjectId = Value(subjectId),
       episodeKey = Value(episodeKey),
       subjectName = Value(subjectName),
       episodeLabel = Value(episodeLabel),
       localPath = Value(localPath),
       format = Value(format),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<DownloadedEpisode> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<int>? subjectId,
    Expression<String>? episodeKey,
    Expression<String>? subjectName,
    Expression<String>? episodeLabel,
    Expression<String>? localPath,
    Expression<String>? format,
    Expression<int>? fileSizeBytes,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? receivedBytes,
    Expression<int>? totalBytes,
    Expression<int>? downloadedSegments,
    Expression<int>? totalSegments,
    Expression<DateTime>? lastProgressAt,
    Expression<String>? episodeDir,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (subjectId != null) 'subject_id': subjectId,
      if (episodeKey != null) 'episode_key': episodeKey,
      if (subjectName != null) 'subject_name': subjectName,
      if (episodeLabel != null) 'episode_label': episodeLabel,
      if (localPath != null) 'local_path': localPath,
      if (format != null) 'format': format,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (receivedBytes != null) 'received_bytes': receivedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedSegments != null) 'downloaded_segments': downloadedSegments,
      if (totalSegments != null) 'total_segments': totalSegments,
      if (lastProgressAt != null) 'last_progress_at': lastProgressAt,
      if (episodeDir != null) 'episode_dir': episodeDir,
    });
  }

  DownloadedEpisodesCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<int>? subjectId,
    Value<String>? episodeKey,
    Value<String>? subjectName,
    Value<String>? episodeLabel,
    Value<String>? localPath,
    Value<String>? format,
    Value<int?>? fileSizeBytes,
    Value<String>? status,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? receivedBytes,
    Value<int?>? totalBytes,
    Value<int?>? downloadedSegments,
    Value<int?>? totalSegments,
    Value<DateTime?>? lastProgressAt,
    Value<String?>? episodeDir,
  }) {
    return DownloadedEpisodesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      subjectId: subjectId ?? this.subjectId,
      episodeKey: episodeKey ?? this.episodeKey,
      subjectName: subjectName ?? this.subjectName,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      localPath: localPath ?? this.localPath,
      format: format ?? this.format,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedSegments: downloadedSegments ?? this.downloadedSegments,
      totalSegments: totalSegments ?? this.totalSegments,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      episodeDir: episodeDir ?? this.episodeDir,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (episodeKey.present) {
      map['episode_key'] = Variable<String>(episodeKey.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (episodeLabel.present) {
      map['episode_label'] = Variable<String>(episodeLabel.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (receivedBytes.present) {
      map['received_bytes'] = Variable<int>(receivedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedSegments.present) {
      map['downloaded_segments'] = Variable<int>(downloadedSegments.value);
    }
    if (totalSegments.present) {
      map['total_segments'] = Variable<int>(totalSegments.value);
    }
    if (lastProgressAt.present) {
      map['last_progress_at'] = Variable<DateTime>(lastProgressAt.value);
    }
    if (episodeDir.present) {
      map['episode_dir'] = Variable<String>(episodeDir.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedEpisodesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodeKey: $episodeKey, ')
          ..write('subjectName: $subjectName, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('localPath: $localPath, ')
          ..write('format: $format, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedSegments: $downloadedSegments, ')
          ..write('totalSegments: $totalSegments, ')
          ..write('lastProgressAt: $lastProgressAt, ')
          ..write('episodeDir: $episodeDir')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $SubjectCollectionsTable subjectCollections =
      $SubjectCollectionsTable(this);
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  late final $SubjectImageCacheTable subjectImageCache =
      $SubjectImageCacheTable(this);
  late final $MikanSubjectMappingsTable mikanSubjectMappings =
      $MikanSubjectMappingsTable(this);
  late final $DownloadedEpisodesTable downloadedEpisodes =
      $DownloadedEpisodesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    subjects,
    episodes,
    subjectCollections,
    searchHistory,
    subjectImageCache,
    mikanSubjectMappings,
    downloadedEpisodes,
  ];
}

typedef $$SubjectsTableCreateCompanionBuilder =
    SubjectsCompanion Function({
      Value<int> id,
      required String name,
      required String nameCn,
      Value<String?> summary,
    });
typedef $$SubjectsTableUpdateCompanionBuilder =
    SubjectsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> nameCn,
      Value<String?> summary,
    });

final class $$SubjectsTableReferences
    extends BaseReferences<_$AppDatabase, $SubjectsTable, Subject> {
  $$SubjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpisodesTable, List<Episode>> _episodesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: $_aliasNameGenerator(db.subjects.id, db.episodes.subjectId),
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SubjectCollectionsTable, List<SubjectCollection>>
  _subjectCollectionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.subjectCollections,
        aliasName: $_aliasNameGenerator(
          db.subjects.id,
          db.subjectCollections.subjectId,
        ),
      );

  $$SubjectCollectionsTableProcessedTableManager get subjectCollectionsRefs {
    final manager = $$SubjectCollectionsTableTableManager(
      $_db,
      $_db.subjectCollections,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _subjectCollectionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> subjectCollectionsRefs(
    Expression<bool> Function($$SubjectCollectionsTableFilterComposer f) f,
  ) {
    final $$SubjectCollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subjectCollections,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectCollectionsTableFilterComposer(
            $db: $db,
            $table: $db.subjectCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameCn =>
      $composableBuilder(column: $table.nameCn, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> subjectCollectionsRefs<T extends Object>(
    Expression<T> Function($$SubjectCollectionsTableAnnotationComposer a) f,
  ) {
    final $$SubjectCollectionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.subjectCollections,
          getReferencedColumn: (t) => t.subjectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SubjectCollectionsTableAnnotationComposer(
                $db: $db,
                $table: $db.subjectCollections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectsTable,
          Subject,
          $$SubjectsTableFilterComposer,
          $$SubjectsTableOrderingComposer,
          $$SubjectsTableAnnotationComposer,
          $$SubjectsTableCreateCompanionBuilder,
          $$SubjectsTableUpdateCompanionBuilder,
          (Subject, $$SubjectsTableReferences),
          Subject,
          PrefetchHooks Function({
            bool episodesRefs,
            bool subjectCollectionsRefs,
          })
        > {
  $$SubjectsTableTableManager(_$AppDatabase db, $SubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameCn = const Value.absent(),
                Value<String?> summary = const Value.absent(),
              }) => SubjectsCompanion(
                id: id,
                name: name,
                nameCn: nameCn,
                summary: summary,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String nameCn,
                Value<String?> summary = const Value.absent(),
              }) => SubjectsCompanion.insert(
                id: id,
                name: name,
                nameCn: nameCn,
                summary: summary,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({episodesRefs = false, subjectCollectionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (episodesRefs) db.episodes,
                    if (subjectCollectionsRefs) db.subjectCollections,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (episodesRefs)
                        await $_getPrefetchedData<
                          Subject,
                          $SubjectsTable,
                          Episode
                        >(
                          currentTable: table,
                          referencedTable: $$SubjectsTableReferences
                              ._episodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).episodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (subjectCollectionsRefs)
                        await $_getPrefetchedData<
                          Subject,
                          $SubjectsTable,
                          SubjectCollection
                        >(
                          currentTable: table,
                          referencedTable: $$SubjectsTableReferences
                              ._subjectCollectionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).subjectCollectionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectsTable,
      Subject,
      $$SubjectsTableFilterComposer,
      $$SubjectsTableOrderingComposer,
      $$SubjectsTableAnnotationComposer,
      $$SubjectsTableCreateCompanionBuilder,
      $$SubjectsTableUpdateCompanionBuilder,
      (Subject, $$SubjectsTableReferences),
      Subject,
      PrefetchHooks Function({bool episodesRefs, bool subjectCollectionsRefs})
    >;
typedef $$EpisodesTableCreateCompanionBuilder =
    EpisodesCompanion Function({
      Value<int> id,
      required int subjectId,
      required String sort,
      required String name,
    });
typedef $$EpisodesTableUpdateCompanionBuilder =
    EpisodesCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> sort,
      Value<String> name,
    });

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, Episode> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SubjectsTable _subjectIdTable(_$AppDatabase db) => db.subjects
      .createAlias($_aliasNameGenerator(db.episodes.subjectId, db.subjects.id));

  $$SubjectsTableProcessedTableManager get subjectId {
    final $_column = $_itemColumn<int>('subject_id')!;

    final manager = $$SubjectsTableTableManager(
      $_db,
      $_db.subjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  $$SubjectsTableFilterComposer get subjectId {
    final $$SubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableFilterComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  $$SubjectsTableOrderingComposer get subjectId {
    final $$SubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  $$SubjectsTableAnnotationComposer get subjectId {
    final $$SubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTable,
          Episode,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (Episode, $$EpisodesTableReferences),
          Episode,
          PrefetchHooks Function({bool subjectId})
        > {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> sort = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                subjectId: subjectId,
                sort: sort,
                name: name,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String sort,
                required String name,
              }) => EpisodesCompanion.insert(
                id: id,
                subjectId: subjectId,
                sort: sort,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable: $$EpisodesTableReferences
                                    ._subjectIdTable(db),
                                referencedColumn: $$EpisodesTableReferences
                                    ._subjectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTable,
      Episode,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (Episode, $$EpisodesTableReferences),
      Episode,
      PrefetchHooks Function({bool subjectId})
    >;
typedef $$SubjectCollectionsTableCreateCompanionBuilder =
    SubjectCollectionsCompanion Function({
      Value<int> subjectId,
      required String collectionType,
      Value<int?> selfRatingScore,
      Value<String?> selfRatingComment,
      Value<bool> isPrivate,
      Value<bool> dirty,
      Value<DateTime?> syncedAt,
    });
typedef $$SubjectCollectionsTableUpdateCompanionBuilder =
    SubjectCollectionsCompanion Function({
      Value<int> subjectId,
      Value<String> collectionType,
      Value<int?> selfRatingScore,
      Value<String?> selfRatingComment,
      Value<bool> isPrivate,
      Value<bool> dirty,
      Value<DateTime?> syncedAt,
    });

final class $$SubjectCollectionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SubjectCollectionsTable,
          SubjectCollection
        > {
  $$SubjectCollectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SubjectsTable _subjectIdTable(_$AppDatabase db) =>
      db.subjects.createAlias(
        $_aliasNameGenerator(db.subjectCollections.subjectId, db.subjects.id),
      );

  $$SubjectsTableProcessedTableManager get subjectId {
    final $_column = $_itemColumn<int>('subject_id')!;

    final manager = $$SubjectsTableTableManager(
      $_db,
      $_db.subjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubjectCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectCollectionsTable> {
  $$SubjectCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get selfRatingScore => $composableBuilder(
    column: $table.selfRatingScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selfRatingComment => $composableBuilder(
    column: $table.selfRatingComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SubjectsTableFilterComposer get subjectId {
    final $$SubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableFilterComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubjectCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectCollectionsTable> {
  $$SubjectCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selfRatingScore => $composableBuilder(
    column: $table.selfRatingScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selfRatingComment => $composableBuilder(
    column: $table.selfRatingComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SubjectsTableOrderingComposer get subjectId {
    final $$SubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubjectCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectCollectionsTable> {
  $$SubjectCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get selfRatingScore => $composableBuilder(
    column: $table.selfRatingScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selfRatingComment => $composableBuilder(
    column: $table.selfRatingComment,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrivate =>
      $composableBuilder(column: $table.isPrivate, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  $$SubjectsTableAnnotationComposer get subjectId {
    final $$SubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubjectCollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectCollectionsTable,
          SubjectCollection,
          $$SubjectCollectionsTableFilterComposer,
          $$SubjectCollectionsTableOrderingComposer,
          $$SubjectCollectionsTableAnnotationComposer,
          $$SubjectCollectionsTableCreateCompanionBuilder,
          $$SubjectCollectionsTableUpdateCompanionBuilder,
          (SubjectCollection, $$SubjectCollectionsTableReferences),
          SubjectCollection,
          PrefetchHooks Function({bool subjectId})
        > {
  $$SubjectCollectionsTableTableManager(
    _$AppDatabase db,
    $SubjectCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectCollectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                Value<String> collectionType = const Value.absent(),
                Value<int?> selfRatingScore = const Value.absent(),
                Value<String?> selfRatingComment = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => SubjectCollectionsCompanion(
                subjectId: subjectId,
                collectionType: collectionType,
                selfRatingScore: selfRatingScore,
                selfRatingComment: selfRatingComment,
                isPrivate: isPrivate,
                dirty: dirty,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                required String collectionType,
                Value<int?> selfRatingScore = const Value.absent(),
                Value<String?> selfRatingComment = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => SubjectCollectionsCompanion.insert(
                subjectId: subjectId,
                collectionType: collectionType,
                selfRatingScore: selfRatingScore,
                selfRatingComment: selfRatingComment,
                isPrivate: isPrivate,
                dirty: dirty,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubjectCollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable:
                                    $$SubjectCollectionsTableReferences
                                        ._subjectIdTable(db),
                                referencedColumn:
                                    $$SubjectCollectionsTableReferences
                                        ._subjectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubjectCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectCollectionsTable,
      SubjectCollection,
      $$SubjectCollectionsTableFilterComposer,
      $$SubjectCollectionsTableOrderingComposer,
      $$SubjectCollectionsTableAnnotationComposer,
      $$SubjectCollectionsTableCreateCompanionBuilder,
      $$SubjectCollectionsTableUpdateCompanionBuilder,
      (SubjectCollection, $$SubjectCollectionsTableReferences),
      SubjectCollection,
      PrefetchHooks Function({bool subjectId})
    >;
typedef $$SearchHistoryTableCreateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      required String query,
      required DateTime searchedAt,
    });
typedef $$SearchHistoryTableUpdateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      Value<String> query,
      Value<DateTime> searchedAt,
    });

class $$SearchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$SearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryTable,
          SearchHistoryData,
          $$SearchHistoryTableFilterComposer,
          $$SearchHistoryTableOrderingComposer,
          $$SearchHistoryTableAnnotationComposer,
          $$SearchHistoryTableCreateCompanionBuilder,
          $$SearchHistoryTableUpdateCompanionBuilder,
          (
            SearchHistoryData,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryTable,
              SearchHistoryData
            >,
          ),
          SearchHistoryData,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableManager(_$AppDatabase db, $SearchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryCompanion(
                id: id,
                query: query,
                searchedAt: searchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String query,
                required DateTime searchedAt,
              }) => SearchHistoryCompanion.insert(
                id: id,
                query: query,
                searchedAt: searchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryTable,
      SearchHistoryData,
      $$SearchHistoryTableFilterComposer,
      $$SearchHistoryTableOrderingComposer,
      $$SearchHistoryTableAnnotationComposer,
      $$SearchHistoryTableCreateCompanionBuilder,
      $$SearchHistoryTableUpdateCompanionBuilder,
      (
        SearchHistoryData,
        BaseReferences<_$AppDatabase, $SearchHistoryTable, SearchHistoryData>,
      ),
      SearchHistoryData,
      PrefetchHooks Function()
    >;
typedef $$SubjectImageCacheTableCreateCompanionBuilder =
    SubjectImageCacheCompanion Function({
      Value<int> subjectId,
      required String imageUrl,
    });
typedef $$SubjectImageCacheTableUpdateCompanionBuilder =
    SubjectImageCacheCompanion Function({
      Value<int> subjectId,
      Value<String> imageUrl,
    });

class $$SubjectImageCacheTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectImageCacheTable> {
  $$SubjectImageCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectImageCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectImageCacheTable> {
  $$SubjectImageCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectImageCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectImageCacheTable> {
  $$SubjectImageCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);
}

class $$SubjectImageCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectImageCacheTable,
          SubjectImageCacheData,
          $$SubjectImageCacheTableFilterComposer,
          $$SubjectImageCacheTableOrderingComposer,
          $$SubjectImageCacheTableAnnotationComposer,
          $$SubjectImageCacheTableCreateCompanionBuilder,
          $$SubjectImageCacheTableUpdateCompanionBuilder,
          (
            SubjectImageCacheData,
            BaseReferences<
              _$AppDatabase,
              $SubjectImageCacheTable,
              SubjectImageCacheData
            >,
          ),
          SubjectImageCacheData,
          PrefetchHooks Function()
        > {
  $$SubjectImageCacheTableTableManager(
    _$AppDatabase db,
    $SubjectImageCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectImageCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectImageCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectImageCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                Value<String> imageUrl = const Value.absent(),
              }) => SubjectImageCacheCompanion(
                subjectId: subjectId,
                imageUrl: imageUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                required String imageUrl,
              }) => SubjectImageCacheCompanion.insert(
                subjectId: subjectId,
                imageUrl: imageUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectImageCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectImageCacheTable,
      SubjectImageCacheData,
      $$SubjectImageCacheTableFilterComposer,
      $$SubjectImageCacheTableOrderingComposer,
      $$SubjectImageCacheTableAnnotationComposer,
      $$SubjectImageCacheTableCreateCompanionBuilder,
      $$SubjectImageCacheTableUpdateCompanionBuilder,
      (
        SubjectImageCacheData,
        BaseReferences<
          _$AppDatabase,
          $SubjectImageCacheTable,
          SubjectImageCacheData
        >,
      ),
      SubjectImageCacheData,
      PrefetchHooks Function()
    >;
typedef $$MikanSubjectMappingsTableCreateCompanionBuilder =
    MikanSubjectMappingsCompanion Function({
      Value<int> subjectId,
      Value<int?> mikanBangumiId,
      required DateTime resolvedAt,
    });
typedef $$MikanSubjectMappingsTableUpdateCompanionBuilder =
    MikanSubjectMappingsCompanion Function({
      Value<int> subjectId,
      Value<int?> mikanBangumiId,
      Value<DateTime> resolvedAt,
    });

class $$MikanSubjectMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $MikanSubjectMappingsTable> {
  $$MikanSubjectMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mikanBangumiId => $composableBuilder(
    column: $table.mikanBangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MikanSubjectMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MikanSubjectMappingsTable> {
  $$MikanSubjectMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mikanBangumiId => $composableBuilder(
    column: $table.mikanBangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MikanSubjectMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MikanSubjectMappingsTable> {
  $$MikanSubjectMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get mikanBangumiId => $composableBuilder(
    column: $table.mikanBangumiId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$MikanSubjectMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MikanSubjectMappingsTable,
          MikanSubjectMapping,
          $$MikanSubjectMappingsTableFilterComposer,
          $$MikanSubjectMappingsTableOrderingComposer,
          $$MikanSubjectMappingsTableAnnotationComposer,
          $$MikanSubjectMappingsTableCreateCompanionBuilder,
          $$MikanSubjectMappingsTableUpdateCompanionBuilder,
          (
            MikanSubjectMapping,
            BaseReferences<
              _$AppDatabase,
              $MikanSubjectMappingsTable,
              MikanSubjectMapping
            >,
          ),
          MikanSubjectMapping,
          PrefetchHooks Function()
        > {
  $$MikanSubjectMappingsTableTableManager(
    _$AppDatabase db,
    $MikanSubjectMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MikanSubjectMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MikanSubjectMappingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MikanSubjectMappingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                Value<int?> mikanBangumiId = const Value.absent(),
                Value<DateTime> resolvedAt = const Value.absent(),
              }) => MikanSubjectMappingsCompanion(
                subjectId: subjectId,
                mikanBangumiId: mikanBangumiId,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                Value<int?> mikanBangumiId = const Value.absent(),
                required DateTime resolvedAt,
              }) => MikanSubjectMappingsCompanion.insert(
                subjectId: subjectId,
                mikanBangumiId: mikanBangumiId,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MikanSubjectMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MikanSubjectMappingsTable,
      MikanSubjectMapping,
      $$MikanSubjectMappingsTableFilterComposer,
      $$MikanSubjectMappingsTableOrderingComposer,
      $$MikanSubjectMappingsTableAnnotationComposer,
      $$MikanSubjectMappingsTableCreateCompanionBuilder,
      $$MikanSubjectMappingsTableUpdateCompanionBuilder,
      (
        MikanSubjectMapping,
        BaseReferences<
          _$AppDatabase,
          $MikanSubjectMappingsTable,
          MikanSubjectMapping
        >,
      ),
      MikanSubjectMapping,
      PrefetchHooks Function()
    >;
typedef $$DownloadedEpisodesTableCreateCompanionBuilder =
    DownloadedEpisodesCompanion Function({
      Value<int> id,
      required String sourceId,
      required int subjectId,
      required String episodeKey,
      required String subjectName,
      required String episodeLabel,
      required String localPath,
      required String format,
      Value<int?> fileSizeBytes,
      required String status,
      Value<String?> errorMessage,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
      Value<int> receivedBytes,
      Value<int?> totalBytes,
      Value<int?> downloadedSegments,
      Value<int?> totalSegments,
      Value<DateTime?> lastProgressAt,
      Value<String?> episodeDir,
    });
typedef $$DownloadedEpisodesTableUpdateCompanionBuilder =
    DownloadedEpisodesCompanion Function({
      Value<int> id,
      Value<String> sourceId,
      Value<int> subjectId,
      Value<String> episodeKey,
      Value<String> subjectName,
      Value<String> episodeLabel,
      Value<String> localPath,
      Value<String> format,
      Value<int?> fileSizeBytes,
      Value<String> status,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> receivedBytes,
      Value<int?> totalBytes,
      Value<int?> downloadedSegments,
      Value<int?> totalSegments,
      Value<DateTime?> lastProgressAt,
      Value<String?> episodeDir,
    });

class $$DownloadedEpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadedEpisodesTable> {
  $$DownloadedEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedSegments => $composableBuilder(
    column: $table.downloadedSegments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSegments => $composableBuilder(
    column: $table.totalSegments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastProgressAt => $composableBuilder(
    column: $table.lastProgressAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeDir => $composableBuilder(
    column: $table.episodeDir,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadedEpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadedEpisodesTable> {
  $$DownloadedEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedSegments => $composableBuilder(
    column: $table.downloadedSegments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSegments => $composableBuilder(
    column: $table.totalSegments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastProgressAt => $composableBuilder(
    column: $table.lastProgressAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeDir => $composableBuilder(
    column: $table.episodeDir,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadedEpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadedEpisodesTable> {
  $$DownloadedEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedSegments => $composableBuilder(
    column: $table.downloadedSegments,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalSegments => $composableBuilder(
    column: $table.totalSegments,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastProgressAt => $composableBuilder(
    column: $table.lastProgressAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeDir => $composableBuilder(
    column: $table.episodeDir,
    builder: (column) => column,
  );
}

class $$DownloadedEpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadedEpisodesTable,
          DownloadedEpisode,
          $$DownloadedEpisodesTableFilterComposer,
          $$DownloadedEpisodesTableOrderingComposer,
          $$DownloadedEpisodesTableAnnotationComposer,
          $$DownloadedEpisodesTableCreateCompanionBuilder,
          $$DownloadedEpisodesTableUpdateCompanionBuilder,
          (
            DownloadedEpisode,
            BaseReferences<
              _$AppDatabase,
              $DownloadedEpisodesTable,
              DownloadedEpisode
            >,
          ),
          DownloadedEpisode,
          PrefetchHooks Function()
        > {
  $$DownloadedEpisodesTableTableManager(
    _$AppDatabase db,
    $DownloadedEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadedEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadedEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadedEpisodesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> episodeKey = const Value.absent(),
                Value<String> subjectName = const Value.absent(),
                Value<String> episodeLabel = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> receivedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> downloadedSegments = const Value.absent(),
                Value<int?> totalSegments = const Value.absent(),
                Value<DateTime?> lastProgressAt = const Value.absent(),
                Value<String?> episodeDir = const Value.absent(),
              }) => DownloadedEpisodesCompanion(
                id: id,
                sourceId: sourceId,
                subjectId: subjectId,
                episodeKey: episodeKey,
                subjectName: subjectName,
                episodeLabel: episodeLabel,
                localPath: localPath,
                format: format,
                fileSizeBytes: fileSizeBytes,
                status: status,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                downloadedSegments: downloadedSegments,
                totalSegments: totalSegments,
                lastProgressAt: lastProgressAt,
                episodeDir: episodeDir,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required int subjectId,
                required String episodeKey,
                required String subjectName,
                required String episodeLabel,
                required String localPath,
                required String format,
                Value<int?> fileSizeBytes = const Value.absent(),
                required String status,
                Value<String?> errorMessage = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> receivedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> downloadedSegments = const Value.absent(),
                Value<int?> totalSegments = const Value.absent(),
                Value<DateTime?> lastProgressAt = const Value.absent(),
                Value<String?> episodeDir = const Value.absent(),
              }) => DownloadedEpisodesCompanion.insert(
                id: id,
                sourceId: sourceId,
                subjectId: subjectId,
                episodeKey: episodeKey,
                subjectName: subjectName,
                episodeLabel: episodeLabel,
                localPath: localPath,
                format: format,
                fileSizeBytes: fileSizeBytes,
                status: status,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                downloadedSegments: downloadedSegments,
                totalSegments: totalSegments,
                lastProgressAt: lastProgressAt,
                episodeDir: episodeDir,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadedEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadedEpisodesTable,
      DownloadedEpisode,
      $$DownloadedEpisodesTableFilterComposer,
      $$DownloadedEpisodesTableOrderingComposer,
      $$DownloadedEpisodesTableAnnotationComposer,
      $$DownloadedEpisodesTableCreateCompanionBuilder,
      $$DownloadedEpisodesTableUpdateCompanionBuilder,
      (
        DownloadedEpisode,
        BaseReferences<
          _$AppDatabase,
          $DownloadedEpisodesTable,
          DownloadedEpisode
        >,
      ),
      DownloadedEpisode,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db, _db.subjects);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$SubjectCollectionsTableTableManager get subjectCollections =>
      $$SubjectCollectionsTableTableManager(_db, _db.subjectCollections);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db, _db.searchHistory);
  $$SubjectImageCacheTableTableManager get subjectImageCache =>
      $$SubjectImageCacheTableTableManager(_db, _db.subjectImageCache);
  $$MikanSubjectMappingsTableTableManager get mikanSubjectMappings =>
      $$MikanSubjectMappingsTableTableManager(_db, _db.mikanSubjectMappings);
  $$DownloadedEpisodesTableTableManager get downloadedEpisodes =>
      $$DownloadedEpisodesTableTableManager(_db, _db.downloadedEpisodes);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the SQLite connection alive across page navigation -- unlike
/// every other provider in this codebase (all `autoDispose`), the DB
/// connection must not be torn down when e.g. the user leaves the
/// collection page, or every provider that reads/writes it would pay a
/// reconnect cost (and, worse, could race a half-closed connection).

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Keeps the SQLite connection alive across page navigation -- unlike
/// every other provider in this codebase (all `autoDispose`), the DB
/// connection must not be torn down when e.g. the user leaves the
/// collection page, or every provider that reads/writes it would pay a
/// reconnect cost (and, worse, could race a half-closed connection).

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Keeps the SQLite connection alive across page navigation -- unlike
  /// every other provider in this codebase (all `autoDispose`), the DB
  /// connection must not be torn down when e.g. the user leaves the
  /// collection page, or every provider that reads/writes it would pay a
  /// reconnect cost (and, worse, could race a half-closed connection).
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'98a09c6cfd43966155dfbdb0787fa18c85438e13';
