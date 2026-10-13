# 游戏盒子（gameBox）

Flutter 写的安卓游戏攻略 App，包名 `com.zhaos.gamebox`。攻略数据不落仓库，运行时从各游戏的公开/官方页面抓取，解析后进本地 SQLite，所以离线也能查。

支持两个游戏：

- **金铲铲之战**：阵容、羁绊、英雄、装备、强化符文、特殊机制（数据源 `jcc.qq.com`）
- **不思议迷宫**：飞艇图鉴、天空机器人、深渊咆哮、神龙许愿、药剂大全、命运石柱、机械祭坛、东方神龛、DP 攻略、天空副本、天空问题、游戏攻略（数据源 3DM / 4399 / 18183）

另外带**应用内自更新**：启动时静默检查新版本，发现就弹窗，下载 APK、校验 sha256、拉起系统安装器完成升级，用户数据不受影响。

## 技术栈

Flutter 3.47.7 / Dart 3.13.5，只构建 Android。

| 用途 | 依赖 |
| --- | --- |
| 状态管理 | `flutter_riverpod` 3.4（Notifier / NotifierProvider） |
| 路由 | `go_router` 18 |
| 本地存储 | `drift` 2.35 + `sqlite3_flutter_libs`（SQLite） |
| 网络抓取 | `dio` 5.11 + `html` + `charset` |
| 偏好设置 | `shared_preferences` |
| 自更新 | `crypto`（sha256）、`package_info_plus`（读当前 versionCode） |
| 规范 | `flutter_lints` 6，格式化行宽 90 |

## 目录结构

```
lib/
  main.dart              入口、GoRouter、启动时静默检查更新
  core/theme.dart        配色与组件样式
  data/
    db.dart (+.g.dart)   drift 表定义与生成的代码
    scraper.dart         Http 封装、ScrapedEntity、GameScraper 抽象基类
    jcc_scraper.dart     金铲铲各栏目解析
    bsy_scraper.dart     不思议迷宫各栏目解析
    app_update.dart      版本清单地址、UpdateInfo、下载与 sha256 校验、安装通道
  state/
    providers.dart       抓取/数据库各 Provider
    settings.dart        设置项
    app_update.dart      AppUpdateNotifier：检查→下载→校验→拉起安装 的状态机
  ui/
    home_screen.dart     首页（两个游戏入口卡片）
    game_popup.dart      游戏选择/栏目
    games/jcc_screen.dart
    games/bsy_screen.dart
    blocks_view.dart     通用栏目列表渲染
    detail_screen.dart   详情页
    settings_screen.dart 设置页（含手动「检查更新」）
    app_update.dart      更新对话框
android/                 Gradle 工程、Manifest、FileProvider、安装通道原生侧
hooks/user_defines.json  国内网络下 sqlite3 预编译产物的镜像地址
icons/app_icon_source.png 应用图标源图
tool/                    gen_icons.py（生成各密度图标）、live_check.dart 与各 probe_*.dart（数据源探针）
test/                    48 个测试：解析器、更新清单、设置
```

## 环境准备与运行

```bash
flutter pub get
flutter run                 # 调试跑在连着的那台设备/模拟器上
```

`android/gradlew`、`gradlew.bat` 和 `gradle-wrapper.jar` 已刻意纳入版本控制（Flutter 模板默认忽略它们），克隆下来不用先装本地 Gradle 就能构建。`gradle-wrapper.properties` 里的 `distributionUrl` 用的是腾讯云镜像；如果它失效，改成 `https\://services.gradle.org/distributions/gradle-9.3.1-all.zip` 即可。

`hooks/user_defines.json` 已经把 `sqlite3` 的预编译产物指到 `gh-proxy.com` 镜像，国内网络直接 `pub get` 即可；如果这个文件删了，`drift` 相关的原生库下载会在无代理环境下失败。

国内依赖镜像变量：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 检查与测试

```bash
dart format --line-length 90 lib test tool
flutter analyze
flutter test
```

基线：`flutter test` 48 个全过；`flutter analyze` 有 7 条 `info`，全部来自探针脚本 `tool/live_check.dart`（3 条 `avoid_relative_lib_imports` + 4 条 `avoid_print`），保留。改动后如果超出这个数，就是新引入的。

## 发布前：签名

正式签名走本地 `android/key.properties`，这个文件和 `*.jks`、`*.keystore` 都在 `.gitignore` 里，**不要提交，也不要贴进任何日志**。

```bash
cp android/key.properties.example android/key.properties
# 改 storeFile / storePassword / keyAlias / keyPassword
```

`android/app/build.gradle.kts` 会在 `key.properties` 存在时用正式 keystore 签 release，不存在时**回落 debug 签名**。回落不影响本地跑，但那个包不能用来发版——debug keystore 是 Android SDK 通用公开密钥，任何人都能签出同包名、可覆盖你 App 的安装包；而且一旦正式发出去，换签名就得让老用户卸载重装。

keystore 自己生成一次、永久保管（丢了就没法给已有用户发更新）：

```bash
keytool -genkeypair -v -keystore ~/gamebox-release.jks -alias gamebox \
  -keyalg RSA -keysize 2048 -validity 10000
```

---

# 如何发新版本

APK 和版本清单都放在这个仓库的 **GitHub Releases** 上，App 读的是
`https://github.com/zhaosai6869/gameBox/releases/latest/download/update.json`。

## 1. 递增版本号

改 `pubspec.yaml`：

```yaml
version: 1.0.3+4
```

`+` 后面的 **versionCode 必须比上一个版本大**（Android 靠它判断是不是更新），前面的 versionName 给人看。当前仓库是 `1.0.2+3`，下一版就是 `1.0.3+4` 之类。

## 2. 构建 release APK

```bash
flutter build apk --release
```

产物在 `build/app/outputs/flutter-apk/app-release.apk`（约 66MB）。清单地址已经是代码里的默认值，正常发版不需要 `--dart-define`。

上传前把它重命名成 `gamebox-v<versionName>-release.apk`，例如 `gamebox-v1.0.3-release.apk`。这个名字会直接出现在下载直链里，对外更清楚；App 不关心文件名，只认清单里的 `apkUrl`。

## 3. 算 sha256 和字节数

```bash
cd build/app/outputs/flutter-apk
sha256sum app-release.apk
stat -c %s app-release.apk      # Linux/Git Bash
# Windows PowerShell:
#   (Get-FileHash app-release.apk -Algorithm SHA256).Hash.ToLower()
#   (Get-Item app-release.apk).Length
```

## 4. 写版本清单 update.json

```json
{
  "versionCode": 4,
  "versionName": "1.0.3",
  "apkUrl": "https://github.com/zhaosai6869/gameBox/releases/download/v1.0.3/gamebox-v1.0.3-release.apk",
  "sha256": "上一步算出的64位小写十六进制",
  "size": 69340461,
  "changelog": "1. 不思议迷宫新增东方神龛栏目\n2. 修复阵容页筛选重置的问题",
  "forceUpdate": false
}
```

字段含义：`versionCode`/`versionName` 对应 pubspec；`apkUrl` 是 Release 资产的直链；`sha256` 校验不一致时 App 会删掉安装包并提示，不会拉起安装；`size` 只用于进度条显示；`changelog` 显示在更新弹窗里；`forceUpdate: true` 时弹窗不可取消。

**注意 `apkUrl` 里的 tag 要写成这一步准备用的 tag**，而 `/releases/latest/download/` 那份 `update.json` 是给 App 的固定入口，两者不要混。

## 5. 建 GitHub Release 并上传两个文件

创建一个 Release，tag 用 `v1.0.3`（和 versionName 对齐），然后**同时上传 `gamebox-v1.0.3-release.apk` 和 `update.json`** 两个资产。

关键：**必须取消勾选 Draft 和 "Set as a pre-release"**。App 走的是 `/releases/latest/download/`，只有标记为 latest 的正式版才能被这个地址解析到；草稿和预发布版本都取不到，用户那边就表现为「检查更新失败」。

用命令行发（需要 [`gh` CLI](https://cli.github.com/)，本机没装时走网页上传一样）：

```bash
gh release create v1.0.3 \
  build/app/outputs/flutter-apk/gamebox-v1.0.3-release.apk \
  update.json \
  --latest --title "1.0.3" --notes "本次更新说明"
```

`--latest` 显式声明这是最新版，避免被别的 Release 抢走 latest 标记。

## 6. 验证

```bash
# 清单能取到、字段对
curl -sL https://github.com/zhaosai6869/gameBox/releases/latest/download/update.json

# 安装包直链可下载（GitHub 会 302 跳到 release-assets，App 里 dio 跟得动）
curl -sIL -o /dev/null -w "%{http_code}\n" \
  https://github.com/zhaosai6869/gameBox/releases/download/v1.0.3/gamebox-v1.0.3-release.apk

# 复核这个包的签名和已装版本一致（不一致的话老用户升级会失败）
"$ANDROID_HOME/build-tools/36.0.0/apksigner.bat" verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

最后一步在旧手机上验证：装着一个低版本，打开 App 应该自动弹更新；设置页里「检查更新」也能手动触发。

## 已发布版本

| tag | versionName | versionCode | 说明 |
| --- | --- | --- | --- |
| `v1.0.2` | 1.0.2 | 3 | 首个正式版，含金铲铲与不思议迷宫资料库及应用内更新 |
| `v1.0.3` | 1.0.3 | 4 | 去掉界面里的来源站与更新时间；修复检查更新总报「版本清单格式不对」 |
| `v1.0.4` | 1.0.4 | 5 | 在线升级自检版，内容与 1.0.3 一致，只递增版本号 |

1.0.2 的资产是 `gamebox-v1.0.2-release.apk`（sha256 `fc3fab8a62bca5b9ba17111418d6d9d1b83bf39bf9b4dd04dcdb1b02bae56bb3`，69,340,461 字节）；1.0.3 的是 `gamebox-v1.0.3-release.apk`（sha256 `dcf2e57166d8f2a919ddbbf14c2c72ee69fbd4e8c3bf1d2386ddb8d514240ffa`，69,324,077 字节）；1.0.4 的是 `gamebox-v1.0.4-release.apk`（sha256 `15fea3b4990d6ac1550f625c7ef65db3b837835feb65f4508a425bd95b316ac0`，69,324,077 字节）。清单都叫 `update.json`。

**已知影响**：1.0.2 这个包带着清单解析的 bug（GitHub 的 Release 资产按 `application/octet-stream` 下发，dio 不解 JSON，`UpdateInfo.fromJson` 收到字符串就判 null），所以**它自己永远收不到更新提示**，设置页只会显示「版本清单格式不对」。1.0.2 → 1.0.3 这一跳必须手动装 APK（同一个正式 keystore 签名，覆盖安装不丢已抓数据）；装上 1.0.3 之后，往后的版本才走应用内自更新。

`update.json` 走的是 GitHub 的资源 CDN，改完重传后线上可能要等一两分钟才刷出新内容，验证时别被旧值误导。

## 本地联调更新链路（不发版）

起一个局域网 http server 假装是发布站点，构建时覆盖清单地址：

```bash
# 在放 app-release.apk 和 update.json 的目录里
python -c "import http.server,socketserver,os; \
socketserver.ThreadingTCPServer.allow_reuse_address=True; \
socketserver.ThreadingTCPServer(('0.0.0.0',8123),http.server.SimpleHTTPRequestHandler).serve_forever()"
```

```bash
flutter build apk --release --dart-define=UPDATE_MANIFEST_URL=http://10.0.2.2:8123/update.json
```

`10.0.2.2` 是模拟器访问宿主机的地址。`update.json` 里的 `apkUrl` 也要指到这个 server 上。

这条路必须走 http 明文，而 Manifest 里已经**没有** `usesCleartextTraffic`（所有正式数据源都是 HTTPS）。联调时临时加回 `android:usesCleartextTraffic="true"`，**测完删掉再提交**。

用 `ThreadingTCPServer` 而不是 `python -m http.server`：后者单线程，66MB 的长下载会把并发请求堵死。

## 已知问题

- **更新后版本号滞后 1–2 分钟**：升级完立刻打开 App，设置页可能还显示旧版本号。这是 Android 侧 package-info 的缓存，重启或等一会儿就好，不是没更新成功（可以看 Downloads 目录或者直接用 `adb shell dumpsys package com.zhaos.gamebox` 核对）。
- **换签名必须卸载重装**，覆盖安装会失败。
- **正式包没配 `key.properties` 时静默回落 debug 签名**，构建不会报错，所以要靠第 6 步的 `apksigner verify` 兜底。
- 抓栏目时如果已有抓取在跑（全局锁），页面级按需抓取会静默跳过，稍后再进页面即可。
