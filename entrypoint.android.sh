#!/bin/bash
set -e

ABI="${1:-arm64-v8a}"

case "$ABI" in
  arm64-v8a)
    RUST_TARGET="aarch64-linux-android"
    FLUTTER_TARGET="android-arm64"
    FEATURES="flutter,hwcodec"
    NDK_LIB="aarch64-linux-android"
    ;;
  armeabi-v7a)
    RUST_TARGET="armv7-linux-androideabi"
    FLUTTER_TARGET="android-arm"
    FEATURES="flutter,hwcodec"
    NDK_LIB="arm-linux-androideabi"
    ;;
  x86_64)
    RUST_TARGET="x86_64-linux-android"
    FLUTTER_TARGET="android-x64"
    FEATURES="flutter"
    NDK_LIB="x86_64-linux-android"
    ;;
  x86)
    RUST_TARGET="i686-linux-android"
    FLUTTER_TARGET="android-x86"
    FEATURES="flutter"
    NDK_LIB="i686-linux-android"
    ;;
  *)
    echo "Usage: $0 {arm64-v8a|armeabi-v7a|x86_64|x86}"
    exit 1
    ;;
esac

echo "==> Building for ABI: $ABI (Rust target: $RUST_TARGET)"

cd /build/rustdesk

# Step 1: Build vcpkg dependencies
echo "==> [1/4] Building vcpkg dependencies..."
bash flutter/build_android_deps.sh "$ABI"

# Step 2: Build Rust native library
echo "==> [2/4] Building Rust native library..."
cargo ndk --platform 21 \
    --target "$RUST_TARGET" \
    --bindgen \
    build --locked --release \
    --features "$FEATURES"

# Step 3: Copy .so files to jniLibs
echo "==> [3/4] Copying .so files to jniLibs..."
mkdir -p "flutter/android/app/src/main/jniLibs/$ABI"
cp "target/$RUST_TARGET/release/liblibrustdesk.so" \
   "flutter/android/app/src/main/jniLibs/$ABI/librustdesk.so"
cp "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${NDK_LIB}/libc++_shared.so" \
   "flutter/android/app/src/main/jniLibs/$ABI/"

# Strip debug symbols
"${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" \
    "flutter/android/app/src/main/jniLibs/$ABI/"*

# Step 4: Build Flutter APK
echo "==> [4/4] Building Flutter APK..."
cd flutter
flutter clean
flutter packages pub get
flutter build apk --release \
    --target-platform "$FLUTTER_TARGET" \
    --split-per-abi

# Show output
echo ""
echo "=========================================="
echo "  Build successful!"
echo "  APK location:"
echo "  $(pwd)/build/app/outputs/flutter-apk/"
echo "=========================================="
ls -lh build/app/outputs/flutter-apk/ 2>/dev/null || echo "(check build output above)"
