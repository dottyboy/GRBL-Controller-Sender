# AppImage packaging

Produces `GRBL-Controller-Sender-x86_64.AppImage`, a self-contained Linux
binary that bundles Qt5 and its other shared-library dependencies, so it
runs on a distro that doesn't have (or has a different version of) Qt5
installed - no CodeTyphon, no package installation on the target machine.

## One-time setup

Download the two build tools (not tracked in this repo - see the root
`.gitignore`'s `tools/*` rule):

```sh
mkdir -p tools/appimage-tools
cd tools/appimage-tools
curl -sL -o linuxdeploy-x86_64.AppImage \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
curl -sL -o appimagetool-x86_64.AppImage \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x *.AppImage
```

## Build

```sh
typhonbuild64 -B --ws=qt5 GRBL-Controller-Sender.ctpr   # produces ./GRBL-Controller-Sender
bash packaging/appimage/build-appimage.sh
```

Output: `GRBL-Controller-Sender-x86_64.AppImage` in the project root
(gitignored - attach it to a GitHub release instead of committing it).
~134MB - the first build downloads `libonnxruntime.so` (~29MB) and
`depth-anything-v2-small.onnx` (~99MB) for Phase 23's depth-map feature
and caches them under `tools/onnxruntime/cache/` (gitignored), so later
rebuilds don't re-fetch them.

## Why not `linuxdeploy-plugin-qt`

The usual way to bundle Qt with linuxdeploy is its Qt plugin, which shells
out to `qmake` to find Qt's plugin directory. On a system where the
default `qmake` on PATH is Qt6's (e.g. only `qt6-base-dev` is installed,
no `qtbase5-dev-tools`), the plugin autodetects Qt6 and aborts with
"Could not find Qt modules to deploy" - even though this app links Qt5
(`libQt5Pas`/LCL's qt5 widgetset). `build-appimage.sh` works around this by
deploying the handful of Qt5 plugins this app actually needs
(`platforms/libqxcb.so` and friends) directly by path via linuxdeploy's
`--library` flag, which resolves their dependency closure without needing
qmake at all, then wires them up with a custom `AppRun` that sets
`QT_PLUGIN_PATH` explicitly. If a future machine building this has a real
Qt5 `qmake` on PATH, the plugin approach would also work, but there's no
need to switch since this one is already verified working.

## Testing

```sh
./GRBL-Controller-Sender-x86_64.AppImage &
sleep 3
pgrep -af 'mount_GRBL.*usr/bin/GRBL-Controller-Sender'   # confirm the REAL process is alive
```

Check by PID, not by grepping window titles for "grbl" - an unrelated
already-open window (a browser tab about this repo, an editor, ...) can
match the title and produce a false "it worked" while the actual process
crashed on startup.

## Known portability limits

- Built and tested only on Linux Mint 22.3 (Ubuntu Noble base, glibc
  2.39-ish). An AppImage's glibc requirement is a floor, not a ceiling -
  it should run on equal-or-newer glibc, but may not run on a notably
  older distro (e.g. Ubuntu 18.04/20.04, Debian 11). Not tested there.
- x86_64 only - this project has no ARM build/test environment.
