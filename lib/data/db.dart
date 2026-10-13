import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

@DataClassName('Entity')
class Entities extends Table {
  TextColumn get uid => text().unique()();
  TextColumn get gameId => text().withDefault(const Constant(''))();
  TextColumn get mode => text().withDefault(const Constant(''))();
  TextColumn get type => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get subtitle => text().withDefault(const Constant(''))();
  TextColumn get thumb => text().withDefault(const Constant(''))();
  TextColumn get payload => text().withDefault(const Constant('[]'))();
  TextColumn get sourceUrl => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get crawledAt => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {uid};
}

@DriftDatabase(tables: [Entities])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'gamebox'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(entities, entities.mode);
        // 旧数据没有模式归属，清掉后按模式重新抓取。
        await (delete(entities)..where((t) => t.mode.equals(''))).go();
      }
      if (from < 9) {
        // 「其他」分区新增特殊机制（mech）类型，清掉重抓。
        await (delete(entities)..where((t) => t.gameId.equals('jcc'))).go();
      }
      if (from < 10) {
        // 特殊机制改按官方 mechanism_tab 的类别归属（奇遇/小精灵），清掉旧的 mech 行重抓。
        await (delete(entities)..where((t) => t.type.equals('mech'))).go();
      }
      if (from < 11) {
        // 阵容/装备里的棋子 id 改成归一到英雄名册的那条，老 payload 的点跳会找不到英雄，清掉重抓这两类。
        await (delete(entities)..where(
              (t) =>
                  t.gameId.equals('jcc') &
                  (t.type.equals('lineup') | t.type.equals('item')),
            ))
            .go();
      }
      if (from < 12) {
        // 冈布奥开始带「阵营 · 称号」分类，旧的 subtitle 只是来源标注，清掉重抓。
        await (delete(
          entities,
        )..where((t) => t.gameId.equals('bsy') & t.type.equals('gumball'))).go();
      }
    },
  );

  Stream<List<Entity>> watch({
    required String gameId,
    String mode = '',
    String? type,
    String? query,
  }) {
    final s = select(entities)
      ..where((t) => t.gameId.equals(gameId) & t.mode.equals(mode));
    if (type != null && type.isNotEmpty) s.where((t) => t.type.equals(type));
    final q = query?.trim();
    if (q != null && q.isNotEmpty) {
      final like = '%$q%';
      s.where((t) => t.title.like(like) | t.subtitle.like(like) | t.payload.like(like));
    }
    s.orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.title)]);
    return s.watch();
  }

  Stream<Entity?> watchUid(String uid) => (select(
    entities,
  )..where((t) => t.uid.equals(uid))).watch().map((l) => l.isEmpty ? null : l.first);

  Future<void> replaceForType(
    String gameId,
    String mode,
    String type,
    List<Entity> rows,
  ) => transaction(() async {
    await (delete(entities)..where(
          (t) => t.gameId.equals(gameId) & t.mode.equals(mode) & t.type.equals(type),
        ))
        .go();
    for (final r in rows) {
      await into(entities).insert(r);
    }
  });

  Future<void> updateOne(Entity row) =>
      into(entities)
          .insert(row, onConflict: DoUpdate((_) => row, target: [entities.uid]));
}
