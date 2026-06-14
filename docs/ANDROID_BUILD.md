# RustDesk Android APK 编译指南 (Docker)

本指南使用 Docker 容器编译 RustDesk Android APK，无需手动配置 Android SDK/NDK、Rust、Flutter 等环境。

## 前置要求

- [Docker](https://docs.docker.com/get-docker/) 已安装并运行
- 至少 **15 GB** 可用磁盘空间（镜像约 5-8 GB，编译产物约 2-3 GB）

## 快速开始

### 第一步：克隆仓库

```bash
git clone https://github.com/rustdesk/rustdesk
cd rustdesk
git submodule update --init --recursive
```

### 第二步：构建 Docker 镜像（仅需一次，约 15-20 分钟）

```bash
docker build -t rustdesk-android-builder -f Dockerfile.android .
```

### 第三步：编译 APK

```bash
# arm64-v8a（推荐，适用于绝大多数真机）
docker run --rm -it \
    -v $PWD:/build/rustdesk \
    -v rustdesk-cargo-cache:/root/.cargo/git \
    -v rustdesk-cargo-registry:/root/.cargo/registry \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed \
    -v rustdesk-gradle-cache:/root/.gradle \
    -v rustdesk-pub-cache:/root/.pub-cache \
    rustdesk-android-builder arm64-v8a

# armeabi-v7a（32 位 ARM，老旧设备）
docker run --rm -it \
    -v $PWD:/build/rustdesk \
    -v rustdesk-cargo-cache:/root/.cargo/git \
    -v rustdesk-cargo-registry:/root/.cargo/registry \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed \
    -v rustdesk-gradle-cache:/root/.gradle \
    -v rustdesk-pub-cache:/root/.pub-cache \
    rustdesk-android-builder armeabi-v7a

# x86_64（64 位模拟器）
docker run --rm -it \
    -v $PWD:/build/rustdesk \
    -v rustdesk-cargo-cache:/root/.cargo/git \
    -v rustdesk-cargo-registry:/root/.cargo/registry \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed \
    -v rustdesk-gradle-cache:/root/.gradle \
    -v rustdesk-pub-cache:/root/.pub-cache \
    rustdesk-android-builder x86_64

# x86（32 位模拟器）
docker run --rm -it \
    -v $PWD:/build/rustdesk \
    -v rustdesk-cargo-cache:/root/.cargo/git \
    -v rustdesk-cargo-registry:/root/.cargo/registry \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed \
    -v rustdesk-gradle-cache:/root/.gradle \
    -v rustdesk-pub-cache:/root/.pub-cache \
    rustdesk-android-builder x86
```

# 注意：如果你在中国大陆，可能需要配置代理才能成功拉取依赖和构建。可以在 `docker run` 命令中添加以下环境变量：

```bash
docker run --rm -it \
    --add-host=host.docker.internal:host-gateway \
    -e HTTP_PROXY=http://host.docker.internal:1087 \
    -e HTTPS_PROXY=http://host.docker.internal:1087 \
    -e ALL_PROXY=http://host.docker.internal:1087   \
    -e http_proxy=http://host.docker.internal:1087   \
    -e https_proxy=http://host.docker.internal:1087   \
    -e all_proxy=http://host.docker.internal:1087   \
    -e GRADLE_OPTS="-Xmx4g -Dhttp.proxyHost=host.docker.internal -Dhttp.proxyPort=1087 -Dhttps.proxyHost=host.docker.internal -Dhttps.proxyPort=1087"   \
    -v "$PWD":/build/rustdesk   \
    -v rustdesk-cargo-cache:/root/.cargo/git   \
    -v rustdesk-cargo-registry:/root/.cargo/registry   \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed   \
    -v rustdesk-gradle-cache:/root/.gradle   \
    -v rustdesk-pub-cache:/root/.pub-cache   \
    rustdesk-android-builder x86_64
```

## APK 产物位置

编译完成后，APK 文件位于：

```
flutter/build/app/outputs/flutter-apk/
```

| 架构 | APK 文件名 |
|------|-----------|
| arm64-v8a | `app-arm64-v8a-release.apk` |
| armeabi-v7a | `app-armeabi-v7a-release.apk` |
| x86_64 | `app-x86_64-release.apk` |
| x86 | `app-x86-release.apk` |

## 镜像内包含的工具链

| 工具 | 版本 |
|------|------|
| Ubuntu | 22.04 |
| OpenJDK | 17 |
| Android SDK | API 34 |
| Android NDK | r28c |
| Rust | 1.75 |
| Flutter | 3.24.5 |
| cargo-ndk | 3.1.2 |
| vcpkg | commit `120deac` |
| CMake | 3.22.1 |

## 常用操作

### 增量编译（跳过 vcpkg）

每次执行 `docker run` 都会重新编译 vcpkg 依赖，如果只需要增量编译 Rust 代码，可以进入容器手动操作：

```bash
docker run --rm -it \
    -v $PWD:/build/rustdesk \
    -v rustdesk-cargo-cache:/root/.cargo/git \
    -v rustdesk-cargo-registry:/root/.cargo/registry \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed \
    -v rustdesk-gradle-cache:/root/.gradle \
    -v rustdesk-pub-cache:/root/.pub-cache \
    --entrypoint /bin/bash \
    rustdesk-android-builder

# 在容器内：
cd /build/rustdesk
cargo ndk --platform 21 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
mkdir -p flutter/android/app/src/main/jniLibs/arm64-v8a
cp target/aarch64-linux-android/release/liblibrustdesk.so flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so
cp $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so flutter/android/app/src/main/jniLibs/arm64-v8a/
cd flutter && flutter clean && flutter packages pub get && flutter build apk --release --target-platform android-arm64 --split-per-abi
```

### 清理缓存卷

```bash
docker volume rm rustdesk-cargo-cache rustdesk-cargo-registry rustdesk-vcpkg-cache rustdesk-gradle-cache rustdesk-pub-cache
```

## 开发调试工作流

编译管线分为三个环节，迭代速度差异很大：

```
vcpkg (C/C++ 依赖)     Rust (原生库)       Flutter (Dart/UI)
 ─────────────────     ─────────────       ────────────────
  一次性，极慢           首次慢，增量快         最快，支持热重载
  改一次就行             改 Rust 代码需重编     改 Dart 代码秒级生效
```

### 推荐策略：Docker + 宿主机混合

| 环节 | 在哪跑 | 频率 |
|------|--------|------|
| vcpkg 编译 C/C++ 依赖 | Docker | 仅首次，或 `vcpkg.json` 变更时 |
| Rust `.so` 编译 | Docker（交互式） | 修改 Rust 代码时 |
| Flutter APK / 热重载 | **macOS 宿主机** | 修改 Dart/Flutter 代码时 |

因为 `.so` 文件编译产出在宿主的 `target/` 目录，Flutter 可以直接读取，所以宿主机上的 `flutter run` 可以直接用 Docker 编译好的 `.so`。

---

### 场景一：只改 Dart/Flutter 代码（最常见）

这种改动完全不需要 Docker，在 macOS 上直接用 Flutter 即可：

```bash
# 1. 连接 Android 真机（USB 调试模式）或启动模拟器
adb devices

# 2. 在 flutter 目录下，hot reload 模式运行（支持热重载）
cd flutter
flutter run --debug --target-platform android-arm64

# 修改 lib/ 下的 .dart 文件后，按 r 热重载，按 R 热重启
```

> **前提**：`flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so` 已经存在（首次通过 Docker 编译产出）。后续只改 Dart 代码不需要重新编译 `.so`。

---

### 场景二：改了 Rust 代码（需要重新编译 .so）

进入 Docker 容器做增量编译（利用 cargo 缓存，通常 1-3 分钟）：

```bash
# 启动交互式容器
docker run --rm -it \
    -v $PWD:/build/rustdesk \
    -v rustdesk-cargo-cache:/root/.cargo/git \
    -v rustdesk-cargo-registry:/root/.cargo/registry \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed \
    -v rustdesk-gradle-cache:/root/.gradle \
    -v rustdesk-pub-cache:/root/.pub-cache \
    --entrypoint /bin/bash \
    rustdesk-android-builder

# === 在容器内执行 ===
cd /build/rustdesk

# 1. 增量编译 Rust（cargo 会自动跳过未变更的 crate）
cargo ndk --platform 21 --target aarch64-linux-android build --locked --release --features flutter,hwcodec

# 2. 复制产物到 jniLibs（Flutter 直接读取这个目录）
mkdir -p flutter/android/app/src/main/jniLibs/arm64-v8a
cp target/aarch64-linux-android/release/liblibrustdesk.so \
   flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so
cp $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so \
   flutter/android/app/src/main/jniLibs/arm64-v8a/

# 3. 退出容器
exit
```

然后在宿主机上：

```bash
cd flutter
# 快速打包 APK 并安装到设备
flutter build apk --debug --target-platform android-arm64 --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk

# 或者直接用 hot reload 模式（推荐，调试体验好）
flutter run --debug --target-platform android-arm64
```

---

### 场景三：创建快速增量编译脚本

将场景二封装成脚本，每次只跑 Rust 增量编译 + 复制 .so：

```bash
# 保存为 rebuild_so.sh
#!/bin/bash
set -e
ABI="${1:-arm64-v8a}"
TARGET="aarch64-linux-android"

docker run --rm \
    -v $PWD:/build/rustdesk \
    -v rustdesk-cargo-cache:/root/.cargo/git \
    -v rustdesk-cargo-registry:/root/.cargo/registry \
    -v rustdesk-vcpkg-cache:/opt/vcpkg/installed \
    -v rustdesk-gradle-cache:/root/.gradle \
    -v rustdesk-pub-cache:/root/.pub-cache \
    --entrypoint /bin/bash \
    rustdesk-android-builder -c "
cd /build/rustdesk && \
cargo ndk --platform 21 --target ${TARGET} build --locked --release --features flutter,hwcodec && \
mkdir -p flutter/android/app/src/main/jniLibs/${ABI} && \
cp target/${TARGET}/release/liblibrustdesk.so flutter/android/app/src/main/jniLibs/${ABI}/librustdesk.so && \
cp \${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${TARGET}/libc++_shared.so flutter/android/app/src/main/jniLibs/${ABI}/ && \
echo '==> .so rebuild done'
"
```

使用：

```bash
chmod +x rebuild_so.sh
./rebuild_so.sh arm64-v8a       # 改完 Rust 代码后跑这个
cd flutter && flutter run       # 然后热重载/调试
```

---

### 场景四：全新完整编译（vcpkg 依赖有变更时）

就是快速开始中的完整 Docker 流程，从头编译 vcpkg + Rust + Flutter，一般只在以下情况需要：

- 首次搭建环境
- `vcpkg.json` 有更新
- 切换了 NDK 版本
- "改不动了，从头来一发试试"

---

### 开发调试建议

| 建议 | 说明 |
|------|------|
| **用 debug 模式调试** | `flutter run --debug` 支持断点、hot reload，比 release 快得多 |
| **真机优于模拟器** | Android 模拟器是 x86 架构，需要编译 x86 的 vcpkg 依赖；真机 ARM64 更方便 |
| **只编译需要的架构** | 开发时只编 arm64-v8a，不要一次编全部四种架构 |
| **不要频繁 `flutter clean`** | 只在遇到奇怪的构建缓存问题时才用 |
| **保留 cargo 缓存卷** | `rustdesk-cargo-cache` 和 `rustdesk-cargo-registry` 两个 Docker volume 让增量编译保持在 1-3 分钟 |

## 远程 Linux 服务器开发工作流

如果你 SSH 到一台 Linux 服务器上开发，事情反而更简单——Linux 原生支持 Android 交叉编译，不需要 Docker 也能跑。

核心问题只有一个：**设备不在服务器旁边，怎么把 APK 装到手机上调试？**

有三种方案，按推荐度排序：

```
方案一         方案二（推荐）          方案三
服务器 ←→ 设备    服务器 → 本地 → 设备      服务器 → 本地 → 设备
  WiFi ADB        rsync .so  +         scp APK +
  热重载 ✅       本地 flutter run       adb install
                 热重载 ✅              热重载 ❌
```

---

### 方案一：WiFi ADB 直连（最佳调试体验）

让远程服务器通过 TCP/IP 直接连上你的 Android 设备，`flutter run` 的热重载完全可用。

**设备端（一次性配置）：**

```bash
# 1. 先用 USB 把手机连到本地电脑，开启 TCP/IP 调试
adb tcpip 5555

# 2. 查看手机 IP
adb shell ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
# 假设得到 192.168.1.100

# 3. 现在可以拔掉 USB 了
```

**服务器端：**

```bash
# 4. SSH 到服务器，连接设备
adb connect 192.168.1.100:5555
adb devices
# 应该显示 192.168.1.100:5555    device

# 5. 完整编译 + 热重载运行
bash flutter/build_android_deps.sh arm64-v8a
cargo ndk --platform 21 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
mkdir -p flutter/android/app/src/main/jniLibs/arm64-v8a
cp target/aarch64-linux-android/release/liblibrustdesk.so flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so
cp $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so flutter/android/app/src/main/jniLibs/arm64-v8a/

cd flutter && flutter run --debug --target-platform android-arm64
# 修改 Dart 代码 → 按 r 热重载，秒级生效
```

**适用条件：**
- 设备 IP 对服务器可达（同一局域网/VPN/公网端口映射）
- 服务器安装了 Android SDK platform-tools（有 adb）

**断连重连：** WiFi ADB 在设备重启后会失效，需要重新 `adb tcpip 5555`。可以在手机上装个 [ADB WiFi](https://play.google.com/store/apps/details?id=com.rair.adbwifi) 之类的工具一键开启（需要 root）。

#### 方案一附：不同网络拓扑下的连接方式

`adb connect` 的本质是 TCP 连接，所以关键在于 **服务器能否访问到设备的 IP:5555**。根据你的网络情况选择：

---

**拓扑 A：同一局域网** ✅ 方案一原文已覆盖，`adb connect 设备IP:5555` 即可。

---

**拓扑 B：不同网络 → Tailscale VPN**

手机和服务器都装 [Tailscale](https://tailscale.com/)（免费，个人使用足够），组成虚拟局域网：

```bash
# 服务器安装
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up    # 得到 100.x.x.x 的虚拟 IP

# 手机：Google Play 搜 Tailscale 安装，登录同一账号
# 设置 → 开启 "Allow LAN access"
```

然后服务器直连手机的 Tailscale IP 即可：

```bash
adb connect 100.64.x.x:5555    # 手机的 Tailscale IP
adb devices                     # 确认连接
cd flutter && flutter run --debug --target-platform android-arm64
```

> **优点：** 不需要公网 IP、不需要改路由器、P2P 直连延迟低、配置一次永久有效。适合长期远程开发。

---

**拓扑 C：手机 USB 插本地电脑，服务器在远端 → SSH 反向隧道**

最常见的场景——手机只能用 USB 连到本地 Mac/PC，但开发环境在服务器上。通过 SSH `-R` 把本地 ADB daemon 端口透传给服务器：

```
📱 ──USB── 💻 本地 Mac ──SSH 隧道── 🖥️ 远程服务器
                       -R 5037:localhost:5037
```

```bash
# === 在本地 Mac 上执行 ===

# 1. USB 连接手机，确认 adb 能识别
adb devices
# List of devices attached
# XXXXXXXX    device

# 2. 开启 TCP/IP 调试模式（让 adb server 对外暴露）
adb tcpip 5555

# 3. 创建 SSH 反向隧道，一条命令启动远程 flutter run
ssh -R 5037:localhost:5037 dev-server \
    "export ANDROID_ADB_SERVER_ADDRESS=localhost && \
     cd ~/rustdesk/flutter && flutter run --debug --target-platform android-arm64"
```

> **工作原理：** SSH `-R 5037:localhost:5037` 把服务器上 `localhost:5037` 映射到你本地 Mac 的 `localhost:5037`（ADB daemon 端口），因此服务器的 `adb` 和 `flutter` 就像直接用 USB 连着你的手机一样。
>
> **需要设置 `ANDROID_ADB_SERVER_ADDRESS`** 环境变量告诉 ADB 走 TCP 而非 Unix socket（ADB 默认优先走 socket，需要显式指定才能经过 SSH 隧道）。

如果本地 Mac 和手机也不在一起（比如手机是远程测试机），也可以把手机单独用 ADB over TCP 暴露后再隧道过去：

```bash
# 场景：手机在家里的 Wi-Fi，你在公司的 Mac 连进去

# 1. 先用方案 A/B 把手机连到家里一台机器
adb connect 手机IP:5555

# 2. 再从那台机器 SSH -R 到公司开发服务器
ssh -R 5037:localhost:5037 dev-server
# 服务器上 adb devices 就能看到手机了
```

---

**拓扑 D：设备完全不可达 → 回到方案二/三**

如果手机跟服务器既不在同一网络、也不能装 VPN、也不能 USB 桥接（比如手机是别人的测试机），就用方案二（rsync .so）或方案三（scp APK）。

---

**四种拓扑速查：**

| 拓扑 | 适用条件 | 方案 | 复杂度 |
|------|------|------|:---:|
| A: 同一局域网 | 服务器和手机在同一 Wi-Fi | `adb connect` 直连 | ⭐ |
| B: 不同网络 | 都能装 Tailscale | Tailscale VPN | ⭐⭐ |
| C: 手机 USB 插本地 | 服务器仅 SSH 可达 | SSH `-R` 反向隧道 | ⭐⭐ |
| D: 完全隔离 | 无直接连接通道 | rsync .so / scp APK | ⭐ |

---

### 方案二：服务器编译 .so + 本地 Flutter 调试（推荐）

服务器只做它擅长的事（vcpkg + Rust 交叉编译），Flutter 热重载和 USB 调试在本地完成。

```
┌─ 远程 Linux 服务器 ─┐          ┌─ 本地 macOS ───────────┐
│                     │          │                        │
│ vcpkg + cargo ndk   │  rsync   │ flutter run --debug    │
│       ↓             │ ──────→  │       ↓                │
│ librustdesk.so      │  .so 文件 │ adb install + 热重载   │
│                     │          │       ↓                │
└─────────────────────┘          │   📱 USB 连接设备       │
                                 └────────────────────────┘
```

**一次性环境搭建（服务器端）：**

```bash
# 在服务器上安装依赖（参考 CI 配置）
# Rust + cargo-ndk + Android NDK + Flutter + vcpkg
# 这些都有，就不展开了
```

**日常开发循环：**

```bash
# === 步骤 1：服务器上编译 .so ===
ssh dev-server
cd ~/rustdesk

# 首次需要编译 vcpkg 依赖
bash flutter/build_android_deps.sh arm64-v8a

# 增量编译 Rust（后续每次改动后执行）
cargo ndk --platform 21 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
mkdir -p flutter/android/app/src/main/jniLibs/arm64-v8a
cp target/aarch64-linux-android/release/liblibrustdesk.so \
   flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so
cp $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so \
   flutter/android/app/src/main/jniLibs/arm64-v8a/

# === 步骤 2：同步 .so 到本地 ===
# 在本地 macOS 执行：
rsync -avz dev-server:~/rustdesk/flutter/android/app/src/main/jniLibs/ \
           ~/rustdesk/flutter/android/app/src/main/jniLibs/

# === 步骤 3：本地 Flutter 热重载调试 ===
cd ~/rustdesk/flutter
flutter run --debug --target-platform android-arm64
```

**封装成脚本（在本地 macOS 上执行）：**

```bash
#!/bin/bash
# sync_and_run.sh —— 一键同步 .so + 启动调试
set -e
SERVER="dev-server"
ABI="arm64-v8a"
TARGET="aarch64-linux-android"

echo "==> Building .so on server..."
ssh $SERVER "cd ~/rustdesk && \
    cargo ndk --platform 21 --target ${TARGET} build --locked --release --features flutter,hwcodec && \
    mkdir -p flutter/android/app/src/main/jniLibs/${ABI} && \
    cp target/${TARGET}/release/liblibrustdesk.so flutter/android/app/src/main/jniLibs/${ABI}/librustdesk.so && \
    cp \${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${TARGET}/libc++_shared.so flutter/android/app/src/main/jniLibs/${ABI}/"

echo "==> Syncing .so to local..."
rsync -avz $SERVER:~/rustdesk/flutter/android/app/src/main/jniLibs/ \
              ~/rustdesk/flutter/android/app/src/main/jniLibs/

echo "==> Starting Flutter debug..."
cd ~/rustdesk/flutter
flutter run --debug --target-platform android-arm64
```

---

### 方案三：服务器编译 APK + scp 安装（最简单）

没有热重载，但最可靠，适合"改一点 → 编译 → 装手机上看看"的节奏。

```bash
# === 在服务器上全量编译 APK ===
ssh dev-server
cd ~/rustdesk
bash flutter/build_android_deps.sh arm64-v8a
cargo ndk --platform 21 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
mkdir -p flutter/android/app/src/main/jniLibs/arm64-v8a
cp target/aarch64-linux-android/release/liblibrustdesk.so flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so
cp $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so flutter/android/app/src/main/jniLibs/arm64-v8a/

cd flutter && flutter build apk --debug --target-platform android-arm64 --split-per-abi
# 退出服务器

# === 在本地拉取 APK 并安装 ===
scp dev-server:~/rustdesk/flutter/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk .
adb install -r app-arm64-v8a-debug.apk
```

**封装成一键脚本：**

```bash
#!/bin/bash
# build_and_install.sh
set -e
SERVER="dev-server"

ssh $SERVER "cd ~/rustdesk && \
    cargo ndk --platform 21 --target aarch64-linux-android build --locked --release --features flutter,hwcodec && \
    mkdir -p flutter/android/app/src/main/jniLibs/arm64-v8a && \
    cp target/aarch64-linux-android/release/liblibrustdesk.so flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so && \
    cp \${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so flutter/android/app/src/main/jniLibs/arm64-v8a/ && \
    cd flutter && flutter build apk --debug --target-platform android-arm64 --split-per-abi"

scp $SERVER:~/rustdesk/flutter/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk /tmp/
adb install -r /tmp/app-arm64-v8a-debug.apk
echo "==> Installed! Starting app..."
adb shell am start -n com.carriez.flutter_hbb/.MainActivity
```

---

### 三种方案速览

| | WiFi ADB | rsync .so | scp APK |
|------|:---:|:---:|:---:|
| **热重载** | ✅ | ✅ | ❌ |
| **断点调试** | ✅ | ✅ | ❌ |
| **网络要求** | 设备 IP 可达服务器 | 仅 SSH | 仅 SSH |
| **Rust 改动迭代** | ~2 min | ~2 min + rsync | ~2 min + scp |
| **Dart 改动迭代** | 秒级 | 秒级 | 需重编 APK |
| **复杂度** | 中 | 中 | 低 |

**我的建议：** 日常开发用方案二，想在手机上快速验证时用方案三的一键脚本，如果网络条件允许（同一局域网），方案一的体验最好。

## 输出说明

- 生成的 APK 使用 **debug 签名**，可直接安装到真机测试
- 如需发布到 Google Play，需在 `flutter/android/app/build.gradle` 中配置自己的 keystore
- 本镜像仅用于编译，不包含签名证书

## 相关文件

| 文件 | 用途 |
|------|------|
| `Dockerfile.android` | Android 编译环境的 Docker 镜像定义 |
| `entrypoint.android.sh` | 容器入口脚本，自动执行完整编译流程 |
| `.github/workflows/flutter-build.yml` | CI 工作流（编译环境配置的权威参考） |
