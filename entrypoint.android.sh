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
    export CFLAGS="-DBROKEN_CLANG_ATOMICS"
    export CXXFLAGS="-DBROKEN_CLANG_ATOMICS"
    ;;
  *)
    echo "Usage: $0 {arm64-v8a|armeabi-v7a|x86_64|x86}"
    exit 1
    ;;
esac

echo "==> Building for ABI: $ABI (Rust target: $RUST_TARGET)"

cd /build/rustdesk

# Step 1: Generate flutter-rust-bridge files when they were not restored from CI artifacts.
if [ ! -f src/bridge_generated.rs ] || [ ! -f flutter/lib/generated_bridge.dart ]; then
    echo "==> [1/5] Generating flutter-rust-bridge files..."
    pushd flutter
    flutter packages pub get
    popd
    flutter_rust_bridge_codegen \
        --rust-input ./src/flutter_ffi.rs \
        --dart-output ./flutter/lib/generated_bridge.dart \
        --c-output ./flutter/macos/Runner/bridge_generated.h
    cp ./flutter/macos/Runner/bridge_generated.h ./flutter/ios/Runner/bridge_generated.h
else
    echo "==> [1/5] flutter-rust-bridge files already exist, skipping generation."
fi

# Step 2: Build vcpkg dependencies
echo "==> [2/5] Building vcpkg dependencies..."
bash flutter/build_android_deps.sh "$ABI"

# Step 3: Build Rust native library
echo "==> [3/5] Building Rust native library..."
cargo ndk --platform 21 \
    --target "$RUST_TARGET" \
    --bindgen \
    build --locked --release \
    --features "$FEATURES"

# Step 4: Copy .so files to jniLibs
echo "==> [4/5] Copying .so files to jniLibs..."
mkdir -p "flutter/android/app/src/main/jniLibs/$ABI"
cp "target/$RUST_TARGET/release/liblibrustdesk.so" \
   "flutter/android/app/src/main/jniLibs/$ABI/librustdesk.so"
cp "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${NDK_LIB}/libc++_shared.so" \
   "flutter/android/app/src/main/jniLibs/$ABI/"

# Strip debug symbols
"${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" \
    "flutter/android/app/src/main/jniLibs/$ABI/"*

# Step 5: Build Flutter APK
echo "==> [5/5] Building Flutter APK..."
sed -i "s/org.gradle.jvmargs=-Xmx1024M/org.gradle.jvmargs=-Xmx2g/g" ./flutter/android/gradle.properties
sed -i "s/signingConfigs.release/signingConfigs.debug/g" ./flutter/android/app/build.gradle
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
