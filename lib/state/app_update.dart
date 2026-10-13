import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/app_update.dart';
import 'providers.dart' show crawlReason;

class AppUpdateState {
  final int localCode;
  final String localName;

  /// 正在取版本清单。
  final bool checking;

  /// 非空即「查到新版」，UI 据此弹更新框。
  final UpdateInfo? remote;

  /// 给用户的回执：未配置、检查失败、已是最新、待授权。
  final String? notice;

  /// 非空即在下载。0..1 是进度，-1 表示服务器没给长度（只能显示已下载量）。
  final double? progress;
  final String? downloadedBytes;

  /// 下载完成并通过 sha256 校验的本地路径。
  final String? apkPath;

  /// 下载或校验失败。
  final String? error;

  const AppUpdateState({
    this.localCode = 0,
    this.localName = '',
    this.checking = false,
    this.remote,
    this.notice,
    this.progress,
    this.downloadedBytes,
    this.apkPath,
    this.error,
  });

  bool get downloading => progress != null;
  bool get readyToInstall => apkPath != null;

  String get versionLabel => localName.isEmpty ? '—' : 'v$localName+$localCode';

  static const _keep = Object();

  /// 这些字段要靠「置回 null」表达状态结束，所以用哨兵区分「不改」和「改没」。
  AppUpdateState copyWith({
    int? localCode,
    String? localName,
    bool? checking,
    Object? remote = _keep,
    Object? notice = _keep,
    Object? progress = _keep,
    Object? downloadedBytes = _keep,
    Object? apkPath = _keep,
    Object? error = _keep,
  }) => AppUpdateState(
    localCode: localCode ?? this.localCode,
    localName: localName ?? this.localName,
    checking: checking ?? this.checking,
    remote: remote == _keep ? this.remote : remote as UpdateInfo?,
    notice: notice == _keep ? this.notice : notice as String?,
    progress: progress == _keep ? this.progress : (progress as num?)?.toDouble(),
    downloadedBytes: downloadedBytes == _keep
        ? this.downloadedBytes
        : downloadedBytes as String?,
    apkPath: apkPath == _keep ? this.apkPath : apkPath as String?,
    error: error == _keep ? this.error : error as String?,
  );
}

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  final AppUpdater _updater = AppUpdater();

  @override
  AppUpdateState build() => const AppUpdateState();

  Future<void> _loadLocal() async {
    if (state.localCode > 0) return;
    final p = await PackageInfo.fromPlatform();
    state = state.copyWith(
      // package_info_plus 10 里安卓的 versionCode 叫 buildNumber。
      localCode: int.tryParse(p.buildNumber) ?? 0,
      localName: p.version,
    );
  }

  /// 检查一次，返回是否有新版。`silent` 时失败不写回执，给启动自动检查用。
  Future<bool> check({bool silent = false}) async {
    await _loadLocal();
    final local = state;
    state = local.copyWith(checking: true, notice: null, error: null);
    try {
      final info = await _updater.fetchManifest();
      final newer = info.versionCode > local.localCode;
      state = local.copyWith(
        checking: false,
        remote: newer ? info : null,
        notice: newer ? null : '已是最新版本 ${local.versionLabel}',
      );
      return newer;
    } catch (e) {
      state = local.copyWith(
        checking: false,
        remote: null,
        notice: silent ? null : crawlReason(e),
        error: silent ? null : crawlReason(e),
      );
      return false;
    }
  }

  /// 下载 → 校验 → 拉起安装器。坏包直接删掉，免得下次装到一半还是坏的。
  Future<void> downloadAndInstall() async {
    final info = state.remote;
    if (info == null || state.downloading) return;
    state = state.copyWith(
      progress: 0,
      downloadedBytes: '0 B',
      notice: null,
      error: null,
      apkPath: null,
    );
    String? path;
    try {
      path = await _updater.download(info, (done, total) {
        state = state.copyWith(
          progress: total > 0 ? done / total : -1,
          downloadedBytes: formatBytes(done),
        );
      });
      if (info.sha256.isNotEmpty) {
        final actual = await _updater.sha256Of(path);
        if (actual != info.sha256) {
          await _updater.removeApk(path);
          state = state.copyWith(
            progress: null,
            downloadedBytes: null,
            error: '安装包校验不一致（sha256 不匹配），已删除',
          );
          return;
        }
      }
      state = state.copyWith(progress: null, downloadedBytes: null, apkPath: path);
      await _launchInstaller();
    } on Object catch (e) {
      if (path != null) await _updater.removeApk(path);
      state = state.copyWith(
        progress: null,
        downloadedBytes: null,
        error: crawlReason(e),
      );
    }
  }

  /// 已经校验过的包再拉一次安装器。
  Future<void> retryInstall() async {
    if (state.apkPath == null) return;
    state = state.copyWith(notice: null);
    await _launchInstaller();
  }

  /// Android 8+ 没拿到「安装未知应用」授权时，系统只会跳到设置页，所以先领一步。
  Future<void> _launchInstaller() async {
    if (!await _updater.canRequestInstall()) {
      state = state.copyWith(notice: '需要先允许「安装未知应用」，授权回来后再点一次安装');
      await _updater.openInstallPermission();
      return;
    }
    try {
      await _updater.install(state.apkPath!);
    } catch (e) {
      state = state.copyWith(error: crawlReason(e));
    }
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
