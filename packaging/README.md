# Packaging

What is actually built, and what is left over from upstream.

## What CI builds — use this

`.github/workflows/release.yml` is the only supported packaging path. It
runs on every push to `master` and `macos-preview`, on tags, and on demand:

| Job | Runner | Produces |
|---|---|---|
| `test` | ubuntu-22.04 | `node --test`, then the Qt Quick suite offscreen |
| `build-appimage` | ubuntu-22.04, Qt 6.10.0 | `nostalgic-terminal-<version>.AppImage` |
| `build-dmg` | macos-14, Qt 6.10.\* | `nostalgic-terminal-<version>.dmg` |
| `release` | — | publishes the artifacts |

`<version>` is `git describe --tags --always --dirty=-dirty`.

Publishing rule:

- **branch push** → force-moves the tag `rolling` and publishes a
  prerelease named *Rolling Release*;
- **tag push** → publishes a normal release under that tag.

All four jobs are gated: nothing is published unless the tests pass and
**both** builds succeed.

### The scripts behind them

| Script | Output | Notable behaviour |
|---|---|---|
| `scripts/build-dmg.sh` | `nostalgic-terminal-<version>.dmg` | `QMAKE_APPLE_DEVICE_ARCHS="x86_64 arm64"` for one universal binary, `macdeployqt -qmldir=app/qml`, **refuses to package** if the app or `libqmltermwidget.dylib` lacks an `x86_64` slice (`lipo -archs`), ad-hoc `codesign`, then `hdiutil create -format UDZO`. |
| `scripts/build-appimage.sh` | `nostalgic-terminal-<version>.AppImage` | Installs into an `AppDir`, relocates the QML import tree, runs `linuxdeploy` with the Qt plugin, excludes unused SQL drivers, then `--plugin qt --output appimage`. |

Run them from the repository root with `qmake` on `PATH`:

```bash
JOBS="$(nproc)"       ./scripts/build-appimage.sh     # Linux
JOBS="$(sysctl -n hw.ncpu)" ./scripts/build-dmg.sh    # macOS
```

## Native packages — legacy, not maintained

The directories below are carried over from upstream cool-retro-term and
target the **Qt 5** era. They have not been updated for Qt 6, for the rename
to `nostalgic-terminal`, or for this fork's features, and they still point at
upstream URLs. Treat them as historical reference:

| Path | Status |
|---|---|
| `packaging/debian/` | Qt 5 build deps, `cool-retro-term` changelog/watch, `cool-retro-term.1` man page. |
| `packaging/rpm/` | Qt 5 `BuildRequires`, upstream `URL:`, version `1.0`. |
| `packaging/appdata/` | Upstream homepage, single release `0.9`. |
| `snap/snapcraft.yaml` | `core18`, `qt-version: qt5`, and a part that **sources the upstream repository**, not this one. |

If any of these is wanted again, start from the CI scripts above and rebuild
the metadata from `nostalgic-terminal.desktop`.

## The desktop entry

`nostalgic-terminal.desktop` at the repository root is current and is
installed by the top-level `.pro` to `/usr/share/applications`. It also
declares a `NewWindow` desktop action.

## Installed layout

| Piece | Destination |
|---|---|
| `nostalgic-terminal` binary | `/usr/bin/` |
| icons 32/64/128/256 | `hicolor` icon theme |
| `nostalgic-terminal.desktop` | `/usr/share/applications` |

`make install INSTALL_ROOT=<dir>` stages this into an AppDir (which is what
the AppImage script does).
