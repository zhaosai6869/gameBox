import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamebox/data/bsy_scraper.dart';
import 'package:gamebox/data/scraper.dart';
import 'package:gamebox/state/providers.dart';
import 'package:gamebox/ui/game_popup.dart';

void main() {
  test('bsy updateSteps 列出主干 + 十二个栏目，共十三步', () async {
    final steps = await BsyScraper(Http()).updateSteps();
    expect(steps.length, 13);
    expect(steps.first.label, '冈布奥图鉴 · 关卡攻略 · 神庙试炼 · 迷宫攻略');
    expect(steps.map((s) => s.label).skip(1).toList(), [
      '飞艇图鉴',
      '天空机器人',
      '深渊咆哮',
      '神龙许愿',
      '药剂大全',
      '命运石柱',
      '机械祭坛',
      '东方神龛',
      'DP 攻略',
      '天空副本',
      '天空问题',
      '游戏攻略',
    ]);
  });

  test('StepResult：0 条不算失败，失败时 detail 就是原因', () {
    expect(const StepResult('机械祭坛', count: 9).detail, '9 条');
    expect(const StepResult('机械祭坛').empty, isTrue);
    expect(const StepResult('机械祭坛').detail, '未抓到内容，已保留原有数据');
    const failed = StepResult('机械祭坛', error: '抓取失败 https://x: SocketException');
    expect(failed.ok, isFalse);
    expect(failed.detail, '抓取失败 https://x: SocketException');
  });

  test('crawlReason：丢掉堆栈，太长掐中间但留住报错尾巴', () {
    expect(
      crawlReason('Exception: 抓取失败 https://x: 超时\nStack trace: #0 foo (bar.dart:1)'),
      '抓取失败 https://x: 超时',
    );
    final long = Exception(
      '抓取失败 https://game.gtimg.cn/images/lol/act/jkzlk/js/config/versiondataconfig.js: '
      'DioException [connection error] SocketException: Failed host lookup: '
      "'game.gtimg.cn' (OS Error: Network is unreachable, errno = 101, address = game.gtimg.cn)",
    );
    final reason = crawlReason(long);
    expect(reason.length, lessThanOrEqualTo(161));
    expect(reason, startsWith('抓取失败 https://game.gtimg.cn'));
    expect(reason, endsWith("errno = 101, address = game.gtimg.cn)"));
  });

  testWidgets('二次确认：取消返回 false，开始更新返回 true，点空白也算取消', (tester) async {
    bool? answer;
    const teal = Color(0xFF37D6C0);
    await tester.pumpWidget(
      MaterialApp(
        // 当前页主色故意设成金铲铲的金色：确认不思议迷宫时按钮必须用它的青色。
        theme: ThemeData(colorSchemeSeed: const Color(0xFFD4A83C), useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () =>
                  confirmFullUpdate(ctx, '不思议迷宫', teal).then((v) => answer = v),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    // 只验确认框本身：三种收尾都必须在开跑前拿到结果。
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('更新 不思议迷宫 全部数据？'), findsOneWidget);
    expect(tester.getSize(find.text('更新 不思议迷宫 全部数据？')).width, greaterThan(0));
    expect(
      tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!
          .backgroundColor!
          .resolve(const <WidgetState>{}),
      teal,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.tap(find.text('开始更新'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.tapAt(const Offset(4, 4)); // 遮罩空白处
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('断网全失败：结果对话框逐条画出原因', (tester) async {
    final results = [
      const StepResult('冈布奥图鉴 · 关卡攻略 · 神庙试炼 · 迷宫攻略', error: _offlineReason),
      for (final l in ['神龙许愿', '药剂大全', '命运石柱', '机械祭坛', '东方神龛', 'DP 攻略', '天空副本', '天空问题'])
        StepResult(l, error: _offlineReason),
      const StepResult('游戏攻略', count: 14),
    ];
    await _openResult(tester, results);
    expect(tester.takeException(), isNull);
    expect(find.text('不思议迷宫 有 9 项失败'), findsOneWidget);
    expect(find.text('1/10 步成功，共写入 14 条'), findsOneWidget);
    // 首屏就得画出第一个栏目名和它的失败原因（这个曾被挤成 0 宽竖排）。
    final firstLabel = find.text(results.first.label);
    expect(tester.getSize(firstLabel).width, greaterThan(0));
    expect(tester.getRect(firstLabel).top, inInclusiveRange(0, 720));
    expect(find.text(_offlineReason), findsWidgets);
    // 后面的栏目在滚动区里，滚到了必须有名字、有原因、有条数。
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('机械祭坛'), 150, scrollable: list);
    expect(tester.getSize(find.text('机械祭坛')).width, greaterThan(0));
    await tester.scrollUntilVisible(find.text('游戏攻略'), 150, scrollable: list);
    expect(find.text('14 条'), findsOneWidget);
    expect(tester.getRect(find.text('知道了')).bottom, lessThan(720));
  });

  testWidgets('全部成功：标题说完成，明细是条数', (tester) async {
    await _openResult(tester, [
      for (final l in ['冈布奥图鉴 · 关卡攻略 · 神庙试炼 · 迷宫攻略', '神龙许愿']) StepResult(l, count: 100),
      const StepResult('游戏攻略', count: 14),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.text('不思议迷宫 更新完成'), findsOneWidget);
    expect(find.text('3 步全部成功，共写入 214 条'), findsOneWidget);
  });
}

/// 断网时 Dio 串里最有信息量的一段，截断后仍可能这么长。
const _offlineReason =
    'DioException [connection error]: 无法连接到 17173.com 的服务器（连接超时） '
    'OS Error on l17173.com:17173, errno = 101 (Network is unreachable), '
    'address = 17173.com, port = 443';

/// 用接近手机的窄屏打开结果对话框——之前的坑就是窄屏上整块不画。
Future<void> _openResult(WidgetTester tester, List<StepResult> results) async {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showUpdateResult(
              Navigator.of(ctx, rootNavigator: true),
              gameName: '不思议迷宫',
              accent: const Color(0xFF37D6C0),
              results: results,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}
