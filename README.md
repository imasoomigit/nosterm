# nostalgic-terminal

| Default Amber | `C:\` IBM DOS | Default Green |
|---|---|---|
| ![Default Amber](https://user-images.githubusercontent.com/121322/32070717-16708784-ba42-11e7-8572-a8fcc10d7f7d.gif) | ![IBM DOS](https://user-images.githubusercontent.com/121322/32070716-16567e5c-ba42-11e7-9e64-ba96dfe9b64d.gif) | ![Default Green](https://user-images.githubusercontent.com/121322/32070715-163a1c94-ba42-11e7-80bb-41fbf10fc634.gif) |

A terminal emulator that mimics the look and feel of the old cathode tube
screens — eye-candy, customizable and reasonably lightweight — wearing an IBM
mainframe's reflexes: a PF/PA key legend printed on the glass, a key click, a
bell, and a CMS command set in your shell.

A fork of [cool-retro-term](https://github.com/Swordfish90/cool-retro-term),
built on the QML port of Konsole's
[qmltermwidget](https://github.com/Swordfish90/qmltermwidget).
Qt 6, Linux and macOS.

---

## Contents

- [Nostalgic mode](#nostalgic-mode)
- [IBM and mainframe extras](#ibm-and-mainframe-extras)
- [PF / PA key legend](#pf--pa-key-legend)
- [Profiles](#profiles)
- [Colour modes](#colour-modes)
- [Splits, tabs and zoom](#splits-tabs-and-zoom)
- [Sound](#sound)
- [CMS command aliases](#cms-command-aliases)
- [Help](#help)
- [Command line](#command-line)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Install](#install)
- [Build from source](#build-from-source)
- [Tests](#tests)
- [Project layout](#project-layout)
- [Releases](#releases)
- [Credits and license](#credits-and-license)

---

## Nostalgic mode

On by default (`Settings → Retro → Interface`). **Full screen is the pure
experience**: no menu bar, no tab strip, no context menu, no size overlay —
nothing on screen hints that a graphical interface is hiding behind the
terminal. Windowed, the menu bar and the right-click menu are back, and every
feature stays reachable from the keyboard either way.

Leave full screen (`F11`, or `Cmd+Ctrl+F` on macOS) at any time; a *New
Window* opened from inside full screen is born full screen, so the shortcut
never pops you out of it.

Setting nostalgic mode off restores the legacy chrome: an optional menu bar,
a tab strip once there is more than one tab, and a resize overlay that
reports the terminal's `cols x rows` for about a second after you stop
dragging.

## IBM and mainframe extras

All of these live in the **Retro** tab of the settings window, and all of
them are switched on by the built-in `IUT-MarkazMohasebat` profile.

| Extra | What it does |
|---|---|
| **PF/PA key legend** | F1..F12 and Ctrl+F1..F3 printed inside the phosphor, below the PTY grid. Opt-in; see the table below. |
| **Key click** | A dry buckling-spring thunk, in three depths: *Tick*, *Deep*, *Deeper*. |
| **Attention bell** | The classic terminal beep when the shell rings. |
| **Active-line highlight** | An iTerm2 style band at the cursor's row, strength adjustable. |
| **Cursor shape** | `Block (3270 / PC BIOS)` — blinking — or `Half block`. |
| **CMS command aliases** | `FILEL`, `COPYFILE`, `ERASE`, … written into your shell profile. |

The legend is drawn as part of the picture, not as a widget: it is picked up
by the same CRT shader as the terminal, so it burns, curves and flickers with
everything else. It deliberately has **no mouse handling at all** — it is
reachable by eye and by key, never by cursor.

## PF / PA key legend

`Settings → Retro → PF / PA Keys` edits every slot's key, sequence, function
and payload text. Out of the box the panel prints (with the arrow glued to
both sides):

```
PF1>>HELP                PF7>>SOUND ON        PA1>>ATTENTION
PF2>>SPLIT VERTICAL      PF8>>SETTINGS
PF3>>CLOSE WINDOW        PF9>>NEW TAB
PF4>>NEXT WINDOW         PF10>>EXIT
PF5>>PREVIOUS WINDOW     PF11>>EXIT FULL SCREEN
PF6>>SPLIT HORIZONTAL    PF12>>NEW WINDOW
```

`PA1` sends `Ctrl+C` to the terminal; `PA2` and `PA3` are left to pass
through to your shell. The factory panel is shaped after the official IBM
defaults — ISPF `F1`=Help, `F2`=Split, `F3`=Exit, `F9`=Swap; CMS `F3`=Quit —
and deliberately keeps shell commands out of it: the CMS command set lives in
the [alias block](#cms-command-aliases) instead.

Twenty-four functions can be bound to any slot, including `Bigger`,
`Smaller`, `Copy`, `Paste`, `Save Profile` and a free-form `Send Text` macro.
`Reset PF/PA keys to defaults` puts the factory panel back.

## Profiles

Fifteen built-ins ship in the list, and any of them can be saved over,
reassigned as the default, reset to its factory values, or exported:

`Default Amber` · `Monochrome Green` · `Deep Blue` · `Commodore 64` ·
`Commodore PET` · `Apple ][` · `Atari 400` · `IBM VGA 8x16` ·
`IBM 3278 Reborn` · `Neon Cyan` · `Ghost Terminal` · `Plasma` · `Boring` ·
`E-Ink` · `IUT-MarkazMohasebat`

`IUT-MarkazMohasebat` is the mainframe profile: IBM 3278 green on black, a
blinking block cursor, no frame — and *every* IBM extra switched on (legend,
tick, bell, line highlight).

- **Save** writes into the profile that is active; the first time nothing is
  active it asks for a name, once.
- **Set as Default** points every future start (and every plain
  *New Window*) at that profile.
- **Reset** restores a built-in from its pristine factory copy. Custom
  profiles have no factory copy and are not resettable.
- Custom profiles can be **Import**ed and **Export**ed as JSON; a mismatched
  `version` field is rejected rather than half-applied.

**Everything you change is saved for you.** A slow poll compares the composed
profile against what was last written and rewrites it only on a real
difference — so a slider drag is one write at the end, not one per frame —
and choosing a profile merely loads it, never rewrites it. With no profile
active, *Save* is still the thing that asks for a name.

*New Window* opens on your default profile; **File → New Window with
Profile** picks any profile by name for the window you are about to open.
Settings are one shared object, so loading a profile is a global switch:
every window follows.

## Colour modes

`Settings → Terminal → Colors` chooses between two ways of putting colour on
the glass:

| Mode | Behaviour |
|---|---|
| **Monochrome** | Everything on the screen — output, the active-line band, the PF legend — collapses onto the profile's one phosphor. Each console colour is read as the luminance it carried, so `ls --color` still varies in brightness, in one hue. |
| **TTY Colours** | The texture keeps the hues the tty painted. Plain white and grey text still wears the profile's phosphor, so the machine keeps its character. |

Five phosphor presets are offered — each is a font colour on pure black — and
any custom pair can be dialed in with the colour buttons:

| Preset | Font | Background |
|---|---|---|
| Black/White | `#ffffff` | `#000000` |
| Black/Green | `#3cff7a` | `#000000` |
| Black/Blue | `#7fb4ff` | `#000000` |
| Black/Yellow | `#ffb000` | `#000000` |
| Black/Red | `#ff5b4d` | `#000000` |

Profiles written before colour modes existed are inferred rather than lost: a
legacy chroma value of `0.5` or more reads as *TTY Colours*, anything below as
*Monochrome*.

## Splits, tabs and zoom

- **Split** — `Window → Split Vertical` / `Split Horizontal` (bound by
  default to `PF2` and `PF6`) toggles a second pane in the current tab, the
  way ISPF's `F2 SPLIT` did. Asking again folds it away. The primary pane
  ending ends the tab; the secondary one just closes the split.
- **One CRT per tab** — panes lay themselves out in a *stage* which is
  captured once and run through the whole two-pass shader chain once. One
  curvature, one bezel, one set of flicker, noise, bloom and burn-in,
  divided or not: the monitor stays whole.
- **Tabs** — `Alt+1..9` (`Cmd+1..9` on macOS) jump straight to a tab; the
  tab strip itself is chrome and stays hidden under nostalgic mode.
- **Zoom** — `Ctrl++` / `Ctrl+-` (or `Cmd`), `Ctrl`+wheel, and the `Bigger`
  / `Smaller` PF functions all step the font scale by `0.05` between
  `0.25` and `2.50`.

## Sound

`Settings → General → Sound` is the master switch (**Enable audible
feedback**), then:

- **Keyboard tick sound** — `Disabled` / `Tick` / `Deep` / `Deeper`. Picking
  a depth auditions it. The click is *observed* without swallowing the key,
  so auto-repeat, paste and bare modifiers never click.
- **Key click** with volume, and the **Terminal bell** with its own volume,
  both `0.00`–`1.00`.

The samples are generated by `scripts/gen-sounds.py` and bundled as
`app/qml/sounds/{keyclick,keyclick-deep,keyclick-deeper,bell}.wav`.
Everything is off until you switch `Enable audible feedback` on; `PF7`
toggles the click and prints `SOUND ON` / `SOUND OFF` in the legend.

## CMS command aliases

`Settings → Retro → Interface` writes one managed block into your shell
profiles. Idempotent: the block is replaced, never appended twice, and
turning it off removes every copy.

| CMS | Shell |
|---|---|
| `FILEL`, `FILELIST` | `ls` |
| `LISTFILE` | `ls -l` |
| `COPYFILE` | `cp` |
| `ERASE` | `rm -i` |
| `RENAME` | `mv` |
| `TYPE` | `cat` |
| `ACCESS` | `mount` |
| `RELEASE` | `umount` |
| `FORMAT` | `mkfs` |
| `HELP` | a shell function: a topic opens `man -- <topic>`, a blank one runs `man -k .` (non-Windows only) |

Targets are `.bashrc` always (created if missing), `.zshrc` on macOS or
wherever it already exists, and `.bash_profile` / `.profile` **only if you
already have them** — profile files are never invented. On Windows the block
is written for Git Bash and gets no `HELP` function.

`SAVE`, `FILE` and `FFILE` belong to XEDIT itself and are deliberately not
aliased; `--default-settings` runs never touch your shell files.

## Help

`PF1` (or the *Help* menu) opens an input field **right in the legend**, the
way a mainframe let you type into its own legend area. A blank topic runs
`man -k .` — listing every page, the way CMS `HELP` with no operand listed
the command set — anything else opens `man -- 'topic'`. If the legend is not
being printed, a dialog takes over and does the same thing.

## Command line

| Option | Effect |
|---|---|
| `-h`, `--help` | Print usage. |
| `-v`, `--version` | Print `nostalgic-terminal <version>`. |
| `--default-settings` | Ignore stored settings, profiles and overrides, and leave your shell profiles alone. |
| `--profile <name>` | Start on the named profile. An unknown name is ignored with a warning. |
| `--workdir <dir>` | Start the shell in `dir` instead of the current directory. |
| `-e <command>` | Run `command` instead of the shell. Consumes every argument after it, so use it last. |
| `--verbose` | Print settings and profile information at startup. |

Launching a second instance is safe: `KDSingleApplication` forwards
"new window" to the running copy instead of starting a second one.

## Keyboard shortcuts

Bindings follow each platform's convention, so the same function always sits
where the operating system puts it.

| Function | Linux / Windows | macOS |
|---|---|---|
| New window | `Ctrl+Shift+N` | `Cmd+N` |
| New tab | `Ctrl+Shift+T` | `Cmd+T` |
| Close tab | `Ctrl+W` | `Cmd+W` |
| Close window | `Ctrl+Shift+W` | `Cmd+Shift+W` |
| Next window | ``Alt+` `` | ``Cmd+` `` |
| Previous window | ``Alt+Shift+` `` | ``Cmd+Shift+` `` |
| Select tab 1…9 | `Alt+1`…`Alt+9` | `Cmd+1`…`Cmd+9` |
| Settings | `Ctrl+,` | `Cmd+,` |
| Fullscreen | `F11` | `Cmd+Ctrl+F` |
| Copy / Paste | `Ctrl+Shift+C/V` | `Cmd+C/V` |
| Zoom in / out | `Ctrl++` / `Ctrl+-` | `Cmd++` / `Cmd+-` |
| Quit | `Ctrl+Shift+Q` | `Cmd+Q` |

`Split Vertical` / `Split Horizontal`, `Bigger` / `Smaller` and the key-click
toggle have no default keyboard binding — assign them to PF keys, or reach
them from the menus.

## Install

Grab the latest build from the
[Releases page](https://github.com/imasoomigit/nosterm/releases): a `.dmg`
for macOS or an `.AppImage` for Linux, named after the commit that produced
them.

- **macOS** — open the `.dmg` and drag `nostalgic-terminal.app` to
  `Applications`. The bundle is a universal binary (`x86_64` + `arm64`), so
  the same file runs on Intel and Apple Silicon.
- **Linux** — `chmod +x nostalgic-terminal-*.AppImage && ./nostalgic-terminal-*.AppImage`.
  The AppImage carries its own Qt.

Branch pushes also publish a rolling prerelease tagged `rolling`, rebuilt on
every push to `master` or `macos-preview`.

## Build from source

You need **Qt 6.8 or newer** (CI builds with 6.10) with the *Qt Shader
Tools*, *Qt 5 Compatibility* and *Qt Multimedia* modules, a C++ toolchain, and
Node 22 for the logic tests. Two submodules supply the terminal widget and
the single-instance helper, so clone them:

```bash
git clone --recurse-submodules https://github.com/imasoomigit/nosterm.git
cd nosterm
[ -d .git/modules ] || git submodule update --init --recursive
```

```bash
qmake nostalgic-terminal.pro
make -j"$(nproc)"
./nostalgic-terminal
```

`qsb` bakes the shader variants as part of the build; the sources under
`app/shaders/*.frag` are the ones you edit, the `.qsb` files are generated.

Add `CONFIG+=build_tests` to `qmake` to build the Qt Quick suite into the
same tree. To produce the distributables instead, run `scripts/build-dmg.sh`
(macOS) or `scripts/build-appimage.sh` (Linux).

## Tests

Two suites, both run in CI on every push:

```bash
node --test                          # pure logic, no Qt needed — from the repo root
mkdir -p build-tests && cd build-tests
qmake ../tests/tests.pro && make -j"$(nproc)"
QT_QPA_PLATFORM=offscreen ./tst_retroterm
```

120 logic tests and 93 Qt Quick tests cover the key map, the PF/PA model,
chrome visibility, window cycling, colour modes, profile round trips, sound
gating, the legend, the line highlight and the shortcuts.

See [`tests/README.md`](tests/README.md) for what each suite covers and how
to add to it.

## Project layout

```
nostalgic-terminal.pro     subdirs: qmltermwidget, app (+ tests, opt-in)
app/
  main.cpp …               C++ shell: engine, file I/O, fonts, single instance
  shaders/                 GLSL sources; .qsb variants are generated
  qml/
    main.qml               appRoot — windows, window cycling, menus
    ApplicationSettings.qml the one settings object; profile round trip
    TerminalWindow.qml     one window: actions, menu bar, PF dispatch
    TerminalTabs.qml       tabs and splits
    TerminalPane.qml       one pane of the stage
    CrtUnit.qml            the CRT: stage → static pass → dynamic pass
    PreprocessedTerminal.qml  the PTY, key observation, mouse mapping
    PfKeyBar.qml           the legend, printed into the picture
    LineHighlight.qml      the active-line band
    Settings*.qml          General / Terminal / Effects / Retro / Advanced
    logic/                 pure JS modules — key map, PF model, profiles,
                           colour modes, chrome, sound, aliases, windows
    menus/                 WindowMenu (target-parameterized) + context menus
    fonts/, sounds/, images/
qmltermwidget/   submodule  QML port of Konsole's qtermwidget
KDSingleApplication/       single-instance forwarding
tests/                     tests.pro, tst_*.qml, logic/*.js
scripts/                   build-dmg.sh, build-appimage.sh, gen-sounds.py
packaging/, snap/          legacy packaging — see packaging/README.md
.github/workflows/         release.yml: test, AppImage, DMG, release
```

## Releases

`.github/workflows/release.yml` runs on every push to `master`,
`macos-preview` and on tags, and does three things in parallel — runs both
test suites, builds the AppImage on Ubuntu and the universal DMG on macOS —
then publishes: a **rolling prerelease** (tag `rolling`) for branch pushes, a
normal release for tags. Artifacts are `nostalgic-terminal-<version>.dmg`
and `nostalgic-terminal-<version>.AppImage`, where `<version>` comes from
`git describe`.

## Credits and license

- Original author: [Filippo Scognamiglio](https://github.com/Swordfish90)
  ([cool-retro-term](https://github.com/Swordfish90/cool-retro-term)).
- Terminal widget: [qmltermwidget](https://github.com/Swordfish90/qmltermwidget),
  the QML port of Konsole's qtermwidget.
- Single instance: [KDSingleApplication](https://github.com/KDAB/KDSingleApplication)
  from [KDAB](https://www.kdab.com).
- This fork: <https://github.com/imasoomigit/nosterm>

Licensed under the **GNU General Public License, version 3**
([`gpl-3.0.txt`](gpl-3.0.txt)); see also [`gpl-2.0.txt`](gpl-2.0.txt) for
portions carried over from the original project.
