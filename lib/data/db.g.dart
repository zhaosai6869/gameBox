// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $EntitiesTable extends Entities with TableInfo<$EntitiesTable, Entity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta('subtitle');
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _thumbMeta = const VerificationMeta('thumb');
  @override
  late final GeneratedColumn<String> thumb = GeneratedColumn<String>(
    'thumb',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _crawledAtMeta = const VerificationMeta('crawledAt');
  @override
  late final GeneratedColumn<String> crawledAt = GeneratedColumn<String>(
    'crawled_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uid,
    gameId,
    mode,
    type,
    title,
    subtitle,
    thumb,
    payload,
    sourceUrl,
    sortOrder,
    crawledAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(_uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    }
    if (data.containsKey('type')) {
      context.handle(_typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    }
    if (data.containsKey('thumb')) {
      context.handle(_thumbMeta, thumb.isAcceptableOrUnknown(data['thumb']!, _thumbMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('crawled_at')) {
      context.handle(
        _crawledAtMeta,
        crawledAt.isAcceptableOrUnknown(data['crawled_at']!, _crawledAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid};
  @override
  Entity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entity(
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      thumb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      crawledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}crawled_at'],
      )!,
    );
  }

  @override
  $EntitiesTable createAlias(String alias) {
    return $EntitiesTable(attachedDatabase, alias);
  }
}

class Entity extends DataClass implements Insertable<Entity> {
  final String uid;
  final String gameId;
  final String mode;
  final String type;
  final String title;
  final String subtitle;
  final String thumb;
  final String payload;
  final String sourceUrl;
  final int sortOrder;
  final String crawledAt;
  const Entity({
    required this.uid,
    required this.gameId,
    required this.mode,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.thumb,
    required this.payload,
    required this.sourceUrl,
    required this.sortOrder,
    required this.crawledAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['game_id'] = Variable<String>(gameId);
    map['mode'] = Variable<String>(mode);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['thumb'] = Variable<String>(thumb);
    map['payload'] = Variable<String>(payload);
    map['source_url'] = Variable<String>(sourceUrl);
    map['sort_order'] = Variable<int>(sortOrder);
    map['crawled_at'] = Variable<String>(crawledAt);
    return map;
  }

  EntitiesCompanion toCompanion(bool nullToAbsent) {
    return EntitiesCompanion(
      uid: Value(uid),
      gameId: Value(gameId),
      mode: Value(mode),
      type: Value(type),
      title: Value(title),
      subtitle: Value(subtitle),
      thumb: Value(thumb),
      payload: Value(payload),
      sourceUrl: Value(sourceUrl),
      sortOrder: Value(sortOrder),
      crawledAt: Value(crawledAt),
    );
  }

  factory Entity.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entity(
      uid: serializer.fromJson<String>(json['uid']),
      gameId: serializer.fromJson<String>(json['gameId']),
      mode: serializer.fromJson<String>(json['mode']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      thumb: serializer.fromJson<String>(json['thumb']),
      payload: serializer.fromJson<String>(json['payload']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      crawledAt: serializer.fromJson<String>(json['crawledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'gameId': serializer.toJson<String>(gameId),
      'mode': serializer.toJson<String>(mode),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'thumb': serializer.toJson<String>(thumb),
      'payload': serializer.toJson<String>(payload),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'crawledAt': serializer.toJson<String>(crawledAt),
    };
  }

  Entity copyWith({
    String? uid,
    String? gameId,
    String? mode,
    String? type,
    String? title,
    String? subtitle,
    String? thumb,
    String? payload,
    String? sourceUrl,
    int? sortOrder,
    String? crawledAt,
  }) => Entity(
    uid: uid ?? this.uid,
    gameId: gameId ?? this.gameId,
    mode: mode ?? this.mode,
    type: type ?? this.type,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    thumb: thumb ?? this.thumb,
    payload: payload ?? this.payload,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    sortOrder: sortOrder ?? this.sortOrder,
    crawledAt: crawledAt ?? this.crawledAt,
  );
  Entity copyWithCompanion(EntitiesCompanion data) {
    return Entity(
      uid: data.uid.present ? data.uid.value : this.uid,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      mode: data.mode.present ? data.mode.value : this.mode,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      thumb: data.thumb.present ? data.thumb.value : this.thumb,
      payload: data.payload.present ? data.payload.value : this.payload,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      crawledAt: data.crawledAt.present ? data.crawledAt.value : this.crawledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entity(')
          ..write('uid: $uid, ')
          ..write('gameId: $gameId, ')
          ..write('mode: $mode, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('thumb: $thumb, ')
          ..write('payload: $payload, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('crawledAt: $crawledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uid,
    gameId,
    mode,
    type,
    title,
    subtitle,
    thumb,
    payload,
    sourceUrl,
    sortOrder,
    crawledAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entity &&
          other.uid == this.uid &&
          other.gameId == this.gameId &&
          other.mode == this.mode &&
          other.type == this.type &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.thumb == this.thumb &&
          other.payload == this.payload &&
          other.sourceUrl == this.sourceUrl &&
          other.sortOrder == this.sortOrder &&
          other.crawledAt == this.crawledAt);
}

class EntitiesCompanion extends UpdateCompanion<Entity> {
  final Value<String> uid;
  final Value<String> gameId;
  final Value<String> mode;
  final Value<String> type;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String> thumb;
  final Value<String> payload;
  final Value<String> sourceUrl;
  final Value<int> sortOrder;
  final Value<String> crawledAt;
  final Value<int> rowid;
  const EntitiesCompanion({
    this.uid = const Value.absent(),
    this.gameId = const Value.absent(),
    this.mode = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.thumb = const Value.absent(),
    this.payload = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.crawledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntitiesCompanion.insert({
    required String uid,
    this.gameId = const Value.absent(),
    this.mode = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.thumb = const Value.absent(),
    this.payload = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.crawledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uid = Value(uid);
  static Insertable<Entity> custom({
    Expression<String>? uid,
    Expression<String>? gameId,
    Expression<String>? mode,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? thumb,
    Expression<String>? payload,
    Expression<String>? sourceUrl,
    Expression<int>? sortOrder,
    Expression<String>? crawledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (gameId != null) 'game_id': gameId,
      if (mode != null) 'mode': mode,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (thumb != null) 'thumb': thumb,
      if (payload != null) 'payload': payload,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (crawledAt != null) 'crawled_at': crawledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntitiesCompanion copyWith({
    Value<String>? uid,
    Value<String>? gameId,
    Value<String>? mode,
    Value<String>? type,
    Value<String>? title,
    Value<String>? subtitle,
    Value<String>? thumb,
    Value<String>? payload,
    Value<String>? sourceUrl,
    Value<int>? sortOrder,
    Value<String>? crawledAt,
    Value<int>? rowid,
  }) {
    return EntitiesCompanion(
      uid: uid ?? this.uid,
      gameId: gameId ?? this.gameId,
      mode: mode ?? this.mode,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      thumb: thumb ?? this.thumb,
      payload: payload ?? this.payload,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      crawledAt: crawledAt ?? this.crawledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (thumb.present) {
      map['thumb'] = Variable<String>(thumb.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (crawledAt.present) {
      map['crawled_at'] = Variable<String>(crawledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntitiesCompanion(')
          ..write('uid: $uid, ')
          ..write('gameId: $gameId, ')
          ..write('mode: $mode, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('thumb: $thumb, ')
          ..write('payload: $payload, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('crawledAt: $crawledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EntitiesTable entities = $EntitiesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [entities];
}

typedef $$EntitiesTableCreateCompanionBuilder = EntitiesCompanion Function({
  required String uid,
  Value<String> gameId,
  Value<String> mode,
  Value<String> type,
  Value<String> title,
  Value<String> subtitle,
  Value<String> thumb,
  Value<String> payload,
  Value<String> sourceUrl,
  Value<int> sortOrder,
  Value<String> crawledAt,
  Value<int> rowid,
});
typedef $$EntitiesTableUpdateCompanionBuilder = EntitiesCompanion Function({
  Value<String> uid,
  Value<String> gameId,
  Value<String> mode,
  Value<String> type,
  Value<String> title,
  Value<String> subtitle,
  Value<String> thumb,
  Value<String> payload,
  Value<String> sourceUrl,
  Value<int> sortOrder,
  Value<String> crawledAt,
  Value<int> rowid,
});

class $$EntitiesTableFilterComposer extends Composer<_$AppDatabase, $EntitiesTable> {
  $$EntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumb => $composableBuilder(
    column: $table.thumb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get crawledAt => $composableBuilder(
    column: $table.crawledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntitiesTableOrderingComposer extends Composer<_$AppDatabase, $EntitiesTable> {
  $$EntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumb => $composableBuilder(
    column: $table.thumb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get crawledAt => $composableBuilder(
    column: $table.crawledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntitiesTableAnnotationComposer extends Composer<_$AppDatabase, $EntitiesTable> {
  $$EntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get thumb =>
      $composableBuilder(column: $table.thumb, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get crawledAt =>
      $composableBuilder(column: $table.crawledAt, builder: (column) => column);
}

class $$EntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntitiesTable,
          Entity,
          $$EntitiesTableFilterComposer,
          $$EntitiesTableOrderingComposer,
          $$EntitiesTableAnnotationComposer,
          $$EntitiesTableCreateCompanionBuilder,
          $$EntitiesTableUpdateCompanionBuilder,
          (Entity, BaseReferences<_$AppDatabase, $EntitiesTable, Entity>),
          Entity,
          PrefetchHooks Function()
        > {
  $$EntitiesTableTableManager(_$AppDatabase db, $EntitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uid = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> thumb = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> crawledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntitiesCompanion(
                uid: uid,
                gameId: gameId,
                mode: mode,
                type: type,
                title: title,
                subtitle: subtitle,
                thumb: thumb,
                payload: payload,
                sourceUrl: sourceUrl,
                sortOrder: sortOrder,
                crawledAt: crawledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uid,
                Value<String> gameId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> thumb = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> crawledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntitiesCompanion.insert(
                uid: uid,
                gameId: gameId,
                mode: mode,
                type: type,
                title: title,
                subtitle: subtitle,
                thumb: thumb,
                payload: payload,
                sourceUrl: sourceUrl,
                sortOrder: sortOrder,
                crawledAt: crawledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntitiesTable, Entity>(table),
                  BaseReferences<_$AppDatabase, $EntitiesTable, Entity>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntitiesTable,
      Entity,
      $$EntitiesTableFilterComposer,
      $$EntitiesTableOrderingComposer,
      $$EntitiesTableAnnotationComposer,
      $$EntitiesTableCreateCompanionBuilder,
      $$EntitiesTableUpdateCompanionBuilder,
      (Entity, BaseReferences<_$AppDatabase, $EntitiesTable, Entity>),
      Entity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EntitiesTableTableManager get entities =>
      $$EntitiesTableTableManager(_db, _db.entities);
}
