import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 版本清单地址，默认指向本仓库 Releases 上那份 update.json。
/// 本机联调用 `--dart-define=UPDATE_MANIFEST_URL=http://10.0.2.2:8123/update.json` 覆盖成局域网 http server。
const manifestUrl = String.fromEnvironment(
  'UPDATE_MANIFEST_URL',
  defaultValue:
      'https://github.com/zhaosai6869/gameBox/releases/latest/download/update.json',
);

/// 清单里的一项发布。字段缺失时按「没有更新」处理，不硬抛。
class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final int size;
  final String changelog;
  final bool force;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.size,
    required this.changelog,
    required this.force,
  });

  static UpdateInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final apkUrl = raw['apkUrl'];
    final code = raw['versionCode'];
    if (apkUrl is! String || apkUrl.isEmpty || code is! num) return null;
    return UpdateInfo(
      versionCode: code.toInt(),
      versionName: raw['versionName'] as String? ?? '',
      apkUrl: apkUrl,
      sha256: '${raw['sha256'] ?? ''}'.toLowerCase(),
      size: raw['size'] is num ? (raw['size'] as num).toInt() : 0,
      changelog: '${raw['changelog'] ?? ''}'.trim(),
      force: raw['forceUpdate'] == true,
    );
  }
}

/// 清单响应体。GitHub 的 Release 资产一律按 `application/octet-stream` 下发，dio
/// 因此不解 JSON 而是给回字符串（实测 1.0.2 就是这样被判成「格式不对」的），
/// 所以字符串和已解析的 Map 两种形态都要认。
UpdateInfo? parseManifestBody(Object? body) {
  if (body is String) {
    try {
      body = jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
  return UpdateInfo.fromJson(body);
}

/// 与原生侧的安装通道：FileProvider 授权 + ACTION_VIEW 拉起系统安装器。
const installerChannel = MethodChannel('com.zhaos.gamebox/install');

class AppUpdater {
  /// 65MB 的包不能套用抓取层的 25 秒收流超时，所以这里自带一个 Dio。
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  Future<UpdateInfo> fetchManifest() async {
    if (manifestUrl.isEmpty) throw Exception('未配置更新地址');
    late final Response<dynamic> r;
    try {
      r = await _dio.get<dynamic>(
        manifestUrl,
        options: Options(responseType: ResponseType.json),
      );
    } on DioException catch (e) {
      throw Exception('取版本清单失败：${e.message ?? e.type}');
    }
    final info = parseManifestBody(r.data);
    if (info == null) throw Exception('版本清单格式不对（缺 versionCode 或 apkUrl）');
    return info;
  }

  /// 下到应用外部私有目录，装完由安装器接管；返回落盘路径。
  Future<String> download(
    UpdateInfo info,
    void Function(double done, double total) onProgress,
  ) async {
    final dir = await getExternalStorageDirectory();
    final tag = info.versionName.isEmpty ? '${info.versionCode}' : info.versionName;
    final out = File('${dir!.path}/gamebox-$tag.apk');
    if (await out.exists()) await out.delete();
    await _dio.download(
      info.apkUrl,
      out.path,
      onReceiveProgress: (received, total) =>
          onProgress(received.toDouble(), total.toDouble()),
    );
    return out.path;
  }

  /// 流式算哈希：整包读进内存会让 65MB 的 APK 在低端机上抖一下。
  Future<String> sha256Of(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  /// Android 8+ 需要「安装未知应用」授权，没授权时系统只会跳到设置页。
  Future<bool> canRequestInstall() async {
    final v = await installerChannel.invokeMethod<bool>('canRequestInstall');
    return v ?? false;
  }

  Future<void> openInstallPermission() =>
      installerChannel.invokeMethod<void>('openInstallPermission');

  Future<void> install(String path) =>
      installerChannel.invokeMethod<void>('install', {'path': path});

  /// 装完（或放弃）后清掉下载的包，别把缓存目录堆满。
  Future<void> removeApk(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // 已经没了就算成功。
    }
  }
}

/// 给 UI 用的可读体积。
String formatBytes(double n) {
  if (n <= 0) return '未知大小';
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = n;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
}
