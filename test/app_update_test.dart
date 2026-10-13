import 'package:flutter_test/flutter_test.dart';
import 'package:gamebox/data/app_update.dart';
import 'package:gamebox/state/app_update.dart';

void main() {
  test('版本清单：字段齐全才认，sha256 归一大小写', () {
    final info = UpdateInfo.fromJson({
      'versionCode': 2,
      'versionName': '1.0.1',
      'apkUrl': 'https://example.com/a.apk',
      'sha256': 'ABCD',
      'size': 123,
      'changelog': ' 修点东西\n',
      'forceUpdate': true,
    })!;
    expect(info.versionCode, 2);
    expect(info.sha256, 'abcd');
    expect(info.changelog, '修点东西');
    expect(info.force, isTrue);
  });

  test('版本清单：缺 versionCode 或 apkUrl 视为无更新而不是崩', () {
    expect(UpdateInfo.fromJson({'versionName': '1.0.1'}), isNull);
    expect(UpdateInfo.fromJson({'versionCode': 2}), isNull);
    expect(UpdateInfo.fromJson({'versionCode': 2, 'apkUrl': ''}), isNull);
    expect(UpdateInfo.fromJson(null), isNull);
  });

  test('版本清单：以字符串下发也能解（GitHub 资产是 octet-stream，dio 不解 JSON）', () {
    const raw =
        '{"versionCode": 4, "versionName": "1.0.3", "apkUrl": "https://x/a.apk", "sha256": "AB"}';
    final info = parseManifestBody(raw)!;
    expect(info.versionCode, 4);
    expect(info.sha256, 'ab');
    expect(parseManifestBody('{"versionCode": 4}'), isNull);
    expect(parseManifestBody('not json at all'), isNull);
  });

  test('进度字段能被 int 写、也能被抹回 null', () {
    // copyWith 的哨兵参数是 Object?，早期版本把 progress 强转 double? 直接抛了。
    final s = const AppUpdateState().copyWith(progress: 0, downloadedBytes: '0 B');
    expect(s.progress, 0.0);
    expect(s.downloading, isTrue);
    final cleared = s.copyWith(progress: null, downloadedBytes: null);
    expect(cleared.progress, isNull);
    expect(cleared.downloading, isFalse);
  });

  test('体积可读，未给长度时不装懂', () {
    expect(formatBytes(90573335), '86 MB');
    expect(formatBytes(0), '未知大小');
  });
}
