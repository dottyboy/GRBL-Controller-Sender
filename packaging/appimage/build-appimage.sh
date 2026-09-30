#!/usr/bin/env bash
# Builds GRBL-Controller-Sender-x86_64.AppImage from the already-compiled
# GRBL-Controller-Sender binary in the project root (run
# `typhonbuild64 -B --ws=qt5 GRBL-Controller-Sender.ctpr` first).
#
# Uses linuxdeploy + appimagetool from tools/appimage-tools/ (see
# packaging/appimage/README.md for how to fetch them).
#
# NOTE: this deliberately does NOT use linuxdeploy-plugin-qt. On a system
# whose default `qmake` on PATH resolves to Qt6 (common - qmake6 is what
# ships qt6-base-dev, and there's no separate qmake5 unless qtbase5-dev-tools
# is installed), the plugin autodetects Qt6 and then fails with "Could not
# find Qt modules to deploy" even though the app links Qt5. Instead we deploy
# the handful of Qt5 platform/image plugins this LCL-Qt5 app actually needs
# by hand, via linuxdeploy's own --library dependency-resolution (no qmake
# involved at all), and ship a custom AppRun that points QT_PLUGIN_PATH at
# them explicitly.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG_DIR="$ROOT_DIR/packaging/appimage"
TOOLS_DIR="$ROOT_DIR/tools/appimage-tools"
APPDIR="$PKG_DIR/AppDir"
BINARY="$ROOT_DIR/GRBL-Controller-Sender"
QT5_PLUGINS="/usr/lib/x86_64-linux-gnu/qt5/plugins"

if [ ! -x "$BINARY" ]; then
  echo "error: $BINARY not found - build it first with typhonbuild64" >&2
  exit 1
fi

for tool in linuxdeploy-x86_64.AppImage appimagetool-x86_64.AppImage; do
  if [ ! -x "$TOOLS_DIR/$tool" ]; then
    echo "error: $TOOLS_DIR/$tool missing or not executable - see packaging/appimage/README.md" >&2
    exit 1
  fi
done

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
cp "$BINARY" "$APPDIR/usr/bin/GRBL-Controller-Sender"

LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"

# Pass 1: main executable + the Qt5/X11 shared libs it links directly.
"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/GRBL-Controller-Sender"

# Pass 2: the Qt5 plugins this app's Qt5 widgetset (LCL qt5 interface) needs
# at runtime - xcb platform plugin is mandatory, the rest are cheap/safe
# extras (jpeg/svg/gif/ico image format support, svg icon engine, GL
# integration for xcb). linuxdeploy resolves and copies each plugin's own
# dependency closure (libxcb-*, libX11-xcb, libQt5XcbQpa, ...) automatically.
PLUGIN_LIBS=(
  "$QT5_PLUGINS/platforms/libqxcb.so"
  "$QT5_PLUGINS/platforms/libqminimal.so"
  "$QT5_PLUGINS/xcbglintegrations/libqxcb-glx-integration.so"
  "$QT5_PLUGINS/xcbglintegrations/libqxcb-egl-integration.so"
  "$QT5_PLUGINS/imageformats/libqjpeg.so"
  "$QT5_PLUGINS/imageformats/libqsvg.so"
  "$QT5_PLUGINS/imageformats/libqgif.so"
  "$QT5_PLUGINS/imageformats/libqico.so"
  "$QT5_PLUGINS/iconengines/libqsvgicon.so"
)
LIB_ARGS=()
for lib in "${PLUGIN_LIBS[@]}"; do
  if [ -f "$lib" ]; then
    LIB_ARGS+=(-l "$lib")
  else
    echo "warning: $lib not found on this system, skipping" >&2
  fi
done
"$LINUXDEPLOY" --appdir "$APPDIR" "${LIB_ARGS[@]}"

# Pass 3: desktop file + icon + AppRun symlink (overwritten by our own
# AppRun below, which additionally sets QT_PLUGIN_PATH).
"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --desktop-file "$PKG_DIR/grbl-controller-sender.desktop" \
  --icon-file "$PKG_DIR/grbl-controller-sender.png"

# Recreate the qt5/plugins/<category>/ layout Qt expects, as symlinks back
# into the flat usr/lib/ linuxdeploy already populated (ELF $ORIGIN rpath
# resolves through symlinks fine, since it's based on the real file's path).
mkdir -p "$APPDIR/usr/lib/qt5/plugins"/{platforms,xcbglintegrations,imageformats,iconengines}
for lib in "${PLUGIN_LIBS[@]}"; do
  [ -f "$lib" ] || continue
  category="$(basename "$(dirname "$lib")")"
  name="$(basename "$lib")"
  ln -sf "../../../$name" "$APPDIR/usr/lib/qt5/plugins/$category/$name"
done

# linuxdeploy left AppRun as a symlink to usr/bin/GRBL-Controller-Sender;
# `rm` it before writing our own script, or `cat >` would follow the
# symlink and clobber the real binary it points at instead of replacing it.
rm -f "$APPDIR/AppRun"
cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$HERE/usr/lib/qt5/plugins"
export QT_QPA_PLATFORM=xcb
exec "$HERE/usr/bin/GRBL-Controller-Sender" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Phase 23's depth-map feature needs two files neither vendored into this
# repo nor shipped by any distro package: the ONNX Runtime C library and
# the depth-anything-v2-small model weights. Bundled here, cached under
# tools/onnxruntime/cache/ (gitignored) so re-running this script doesn't
# re-download ~115MB every time. Placed in onnx-models/ right next to the
# executable - same "ExtractFilePath(ParamStr(0)) + '<name>' + PathDelim"
# convention src/ui/ufirmwarebuilderframe.pas already uses for references/,
# so it resolves identically whether run from an AppImage's usr/bin/ or a
# plain dev build's project root.
ONNX_CACHE="$ROOT_DIR/tools/onnxruntime/cache"
ONNXRUNTIME_VERSION="1.30.0"
ONNXRUNTIME_TGZ="onnxruntime-linux-x64-$ONNXRUNTIME_VERSION.tgz"
ONNXRUNTIME_URL="https://github.com/microsoft/onnxruntime/releases/download/v$ONNXRUNTIME_VERSION/$ONNXRUNTIME_TGZ"
DEPTH_MODEL_URL="https://huggingface.co/onnx-community/depth-anything-v2-small/resolve/main/onnx/model.onnx"

mkdir -p "$ONNX_CACHE"

if [ ! -f "$ONNX_CACHE/libonnxruntime.so.$ONNXRUNTIME_VERSION" ]; then
  echo "fetching ONNX Runtime $ONNXRUNTIME_VERSION (cached afterward)..."
  curl -sL --fail -o "$ONNX_CACHE/$ONNXRUNTIME_TGZ" "$ONNXRUNTIME_URL"
  tar xzf "$ONNX_CACHE/$ONNXRUNTIME_TGZ" -C "$ONNX_CACHE" \
    "onnxruntime-linux-x64-$ONNXRUNTIME_VERSION/lib/libonnxruntime.so.$ONNXRUNTIME_VERSION"
  mv "$ONNX_CACHE/onnxruntime-linux-x64-$ONNXRUNTIME_VERSION/lib/libonnxruntime.so.$ONNXRUNTIME_VERSION" "$ONNX_CACHE/"
  rm -rf "$ONNX_CACHE/onnxruntime-linux-x64-$ONNXRUNTIME_VERSION" "$ONNX_CACHE/$ONNXRUNTIME_TGZ"
fi

if [ ! -f "$ONNX_CACHE/depth-anything-v2-small.onnx" ]; then
  echo "fetching depth-anything-v2-small.onnx (~99MB, cached afterward)..."
  curl -sL --fail -o "$ONNX_CACHE/depth-anything-v2-small.onnx" "$DEPTH_MODEL_URL"
fi

mkdir -p "$APPDIR/usr/bin/onnx-models"
cp "$ONNX_CACHE/libonnxruntime.so.$ONNXRUNTIME_VERSION" "$APPDIR/usr/bin/onnx-models/libonnxruntime.so"
cp "$ONNX_CACHE/depth-anything-v2-small.onnx" "$APPDIR/usr/bin/onnx-models/depth-anything-v2-small.onnx"

"$TOOLS_DIR/appimagetool-x86_64.AppImage" "$APPDIR" "$ROOT_DIR/GRBL-Controller-Sender-x86_64.AppImage"

echo "done: $ROOT_DIR/GRBL-Controller-Sender-x86_64.AppImage"
