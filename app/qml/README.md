# Application QML

How the application is put together, and where to change things.

Everything here is QML + plain JavaScript. The C++ side (`app/*.cpp`) is a
thin shell: it starts the engine, exposes file I/O, the font model and
`KDSingleApplication`, and sets the `appVersion` / `workdir` context
properties. It has no feature logic.

---

## The shape of it

```
main.qml                       appRoot (a QtObject, not a window)
 ├─ ApplicationSettings        the ONE settings object — every window shares it
 ├─ SettingsWindow             created once, shown/hidden on demand
 ├─ AboutDialog
 ├─ windowsModel               the list of live windows
 └─ TerminalWindow  × n        one per window
      ├─ menuBar: WindowMenu   target: terminalWindow
      ├─ menuActions           the actions, published for other windows' bars
      ├─ terminalTabs          tabs, splits, panes
      └─ HelpDialog
```

`main.qml` owns the *list* of windows and the app-wide operations on it
(`createWindow`, `closeWindow`, `cycleWindows`, `activateWindow`). Each
`TerminalWindow` owns its own actions and its own menu bar.

### One settings object

`ApplicationSettings.qml` is a `QtObject` singleton-per-document: there is
exactly one, declared in `main.qml`, and every window binds to it. There is
no per-window copy and no second source of truth. Consequences worth
knowing:

- Changing a setting changes it everywhere, at once, with no Apply button.
- Loading a profile is therefore a **global switch** — every window follows.
- A *new window* opens on a profile precisely because the profile is loaded
  before the window is created (see `main.qml: createWindow`).

**The profile round trip** is the contract to keep intact:

| Direction | Function |
|---|---|
| settings → string | `composeSettingsString()` |
| settings → profile string | `composeProfileString()` |
| profile string → settings | `loadProfileString()` |
| settings → storage | `storeSettings()` |

A property that exists in one must exist in the other, or a profile silently
loses that knob when it is saved. `tests/logic/defaults.test.js` asserts the
round trip.

**Autosave** (`autoSaveTimer`, 750 ms) composes both blobs, compares them to
the last pair written, and rewrites only on a real difference. It writes the
session snapshot always, and `writeProfile(activeProfileName, …)` only when a
profile is active. `loadProfileString()` ends with `rebaseAutoSave()` so that
*loading* a profile can never be mistaken for *changing* it.

---

## Where the logic lives

`app/qml/logic/*.js` are pure modules — no `Qt.*`, no globals — imported by
QML with `import "logic/x.js" as X` and by the Node suite through a
`module.exports` guard. This split is deliberate: it is what lets 120 tests
run with no Qt, no build and no display.

| Module | Decides |
|---|---|
| `platform.js` | The named key map, per-platform spellings and alternates. |
| `pfkeys.js` | PF/PA slots, the action catalogue, legend text, help command, macro escapes. |
| `chrome.js` | Which chrome (menu bar, context menu, tab strip, size overlay) is visible, for a given mode/platform/full-screen state. |
| `windows.js` | Cycling, closing order, full-screen inheritance, which profile a new window loads. |
| `profiles.js` | Startup/load/active/default name resolution, factory copies, built-in overrides. |
| `colormode.js` | Monochrome vs TTY colour semantics, phosphor presets, legacy inference. |
| `defaults.js` | Factory settings and `RetroDefaults` (the IBM extras a profile carries). |
| `sound.js` | Whether a click or bell may sound, and from which sample. |
| `aliases.js` | The CMS alias block: content, markers, targets, upsert, strip. |
| `linehighlight.js` | The active-line band. |
| `ibmprofile.js` | The built-in `IUT-MarkazMohasebat` profile, composed at runtime. |

**Rule of thumb:** if a decision can be made without a window, it belongs in
`logic/`, not in a `.qml` file.

---

## The picture

A tab is rendered through exactly one CRT:

```
TerminalPane(s)          the PTY contents, laid out in a stage
   └─ stage              captured once as a texture
        └─ static pass   curve, RGB shift, bloom, frame shine
             └─ dynamic pass   phosphor, burn-in, flicker, noise, bezel
                  └─ screen
```

- `CrtUnit.qml` is the CRT for a whole tab. Split panes share it: they
  contribute to the stage, not to their own shader chain. One curvature, one
  bezel, one set of effects, divided or not.
- `ShaderTerminal.qml` picks the compiled `.qsb` variant for the current
  settings (`raster{0-4}`, `burn{0,1}`, `frame{0,1}`, `chroma{0,1}`). The
  variants are baked from `app/shaders/*.frag` by `app/app.pro` — edit the
  `.frag`, never the `.qsb`.
- `PreprocessedTerminal.qml` owns the PTY, observes keys **without
  swallowing them** (`Keys.BeforeItem` + `event.accepted = false`) so the
  click can be heard and the key still reaches the shell, and maps the mouse
  back through the curvature.
- `PfKeyBar.qml` and `LineHighlight.qml` are drawn *inside* the picture, so
  they get the same CRT as the terminal. `PfKeyBar` has no mouse handling at
  all by design.

`chroma` in the shader is the monochrome/colour switch: `CRT_CHROMA == 1`
prints the tty's hues, `0` collapses everything onto the profile's phosphor.
`ColorMode.shaderChromaFlag(appSettings.colorMode)` is the only thing that
chooses it.

---

## Menus

`menus/WindowMenu.qml` is **one** `MenuBar` component used by two different
windows. It takes:

```qml
property var target: null        // the terminal window these menus act on
readonly property var actionSet: target ? target.menuActions : null
```

A menu bar is built from the *active* window, and on macOS that is global.
Settings is a window too, so it offers the same bar aimed at whichever
terminal was last active — otherwise the whole menu empties while Settings
is focused. That is only possible because every item reaches its action
through `target`, never through an id: **an id declared in one file is not
visible in another**. `TerminalWindow.menuActions` is the published `QtObject`
that makes the cross-file reference legal.

Two things live outside the bar because they are context-driven:
`ShortContextMenu` / `FullContextMenu` (which one appears depends on
platform, nostalgic mode and full screen — see `PreprocessedTerminal.qml`),
and the reveal of a hidden menu bar.

---

## Recipes

### Add a setting

1. Declare the property with its default in `ApplicationSettings.qml`.
2. Add it to `composeSettingsString()` **and** handle it in
   `loadSettingsString()`.
3. If it is a profile value rather than an app value, put it in
   `composeProfileString()` / `loadProfileString()` instead — and if the IBM
   extras should carry it, add it to `RetroDefaults` in `logic/defaults.js`.
4. Bind a control to it in the right `Settings*Tab.qml`.
5. Extend the round-trip test in `tests/logic/defaults.test.js`.

There is no Apply and no Save button for it: the autosave picks it up.

### Add a PF function

1. Add the entry to `ACTIONS` in `logic/pfkeys.js` (`id`, `label`, `kind`).
2. If `kind === "app"`, add a `case` to `TerminalWindow.dispatchAppAction()`.
   If `kind === "term"`, give it a payload or a `commandFor(id, os)`.
3. The Retro tab's Function combo box reads `PfKeys.ACTIONS` — it updates
   itself.
4. Assert the label in `tests/logic/pfkeys.test.js`.

### Add a keyboard shortcut

1. Add the named sequence to `sequences(os)` in `logic/platform.js`.
2. Add an `Action` in `TerminalWindow.qml` using `seq("name")`.
3. If it must also work in full screen, register the physical spellings with
   an application-scoped `Shortcut` (see how zoom does it).
4. Cover both platforms in `tests/logic/platform.test.js`.

### Add a test

See [`tests/README.md`](../../tests/README.md). Short version: logic goes in
`tests/logic/*.test.js` and runs with `node --test` from the repo root; a
component test is a new `tests/tst_*.qml`, picked up automatically.

---

## Conventions

- **No ids across files.** Publish what others need as a property.
- **Comments say why.** The files explain decisions and constraints, not
  syntax.
- **State the invariant.** Where behaviour is a rule ("the legend must have
  no mouse handling", "a load is not a change"), say so next to the code that
  keeps it, and make a test agree.
- **Chrome is a decision, not a pile of bindings.** Ask
  `Chrome.visibility(...)`; do not re-derive the rules locally.
- **Warnings are allowed, errors are not.** `qmllint` on a touched file
  should report zero errors; the standing warnings (C++ types such as
  `FontManager`, unqualified access in delegates, chained aliases) are known
  and accepted.
