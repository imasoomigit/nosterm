# Tests

Two suites cover the app, and both run in CI on every push
(`.github/workflows/release.yml`, job `test`).

| Suite | Needs Qt? | Run from | Count |
|---|---|---|---|
| Node logic tests | no | **repository root** | 120 |
| Qt Quick tests | yes | any build dir | 93 |

---

## 1. Node logic tests

```bash
# from the repository root — not from tests/logic
node --test
```

> Run it from the repo root. `node --test tests/logic` resolves the test
> files but not their imports of `app/qml/logic/*.js` and fails with
> `MODULE_NOT_FOUND`.

Everything under `tests/logic/*.test.js` exercises a **pure** module under
`app/qml/logic/`. Those modules are plain JavaScript with no Qt dependency,
and each ends with the usual guard so the same file loads in both Node and
the QML engine:

```js
if (typeof module !== "undefined" && module.exports) {
    module.exports = { /* … */ }
}
```

| File | Covers |
|---|---|
| `platform.test.js` | The named key map and its per-platform spellings. |
| `pfkeys.test.js` | The PF/PA model: default keys, labels, legend text, action catalogue, help command, macro escapes. |
| `chrome.test.js` | Which chrome is visible for a given mode / platform / full screen state. |
| `windows.test.js` | Window cycling, closing order, full-screen inheritance, which profile a new window loads. |
| `profiles.test.js` | Startup name resolution, factory copies, built-in overrides, save targets. |
| `colormode.test.js` | Monochrome vs TTY colour semantics, phosphor presets, legacy inference. |
| `defaults.test.js` | The settings defaults and the profile/settings round trip. |
| `sound.test.js` | Click/bell gating, auto-repeat and paste suppression, sample sources, volume clamping. |
| `aliases.test.js` | The CMS alias block: content, markers, idempotent upsert, platform targets, stripping. |
| `linehighlight.test.js` | The active-line band's geometry and opacity. |

### Adding one

1. Put the behaviour in `app/qml/logic/<module>.js` as a pure function — no
   `Qt.*`, no DOM, no globals.
2. Export it through the `module.exports` guard.
3. Add `tests/logic/<module>.test.js`:

   ```js
   'use strict'
   const { test } = require('node:test')
   const assert = require('node:assert/strict')
   const Thing = require('../../app/qml/logic/<module>.js')

   test('it explains itself', () => {
     assert.equal(Thing.doTheThing(2), 4)
   })
   ```

4. `node --test` — no build step, no Qt, no display.

---

## 2. Qt Quick test suite

```bash
mkdir -p build-tests && cd build-tests
qmake ../tests/tests.pro      # or: qmake CONFIG+=build_tests at the top level
make -j"$(nproc)"
QT_QPA_PLATFORM=offscreen ./tst_retroterm
```

`CONFIG += qmltestcase` makes qmake define `QUICK_TEST_SOURCE_DIR` as
`tests/`, so **every `tst_*.qml` in this directory is discovered and run
automatically** — dropping a file in is enough to register it.

These are not mocked: the QML tests `import` the very sources the application
ships, straight out of `../app/qml`. `testdata.qrc` bundles the real key
click and bell under the same URLs `SoundBackend` asks for, so the sound test
can assert they actually decode.

| File | Covers |
|---|---|
| `tst_logic.qml` | The shared `logic/*.js` modules as the QML engine sees them — the mirror of the Node suite, plus QML-only wiring. |
| `tst_pfkeybar.qml` | The legend: cell building, the glued `>>`, per-cell text, the PTY reserve, and that it stays unreachable by mouse. |
| `tst_linehighlight.qml` | The active-line band's placement and opacity. |
| `tst_soundmanager.qml` | The sound manager's gates and volumes, including a real decode of the bundled samples. |
| `tst_keysobserve.qml` | The observe-without-swallowing key hook: clicks are reported and the key still reaches the terminal. |
| `tst_shortcuts.qml` | Shortcut resolution and the zoom rungs. |
| `tst_helpdialog.qml` | HELP topic handling: blank → `man -k .`, anything else → `man -- 'topic'`. |

### Adding one

Create `tests/tst_<thing>.qml` with a `TestCase { name: "…" }`. Remember
that `tst_quick.cpp` registers **no** context properties, so a component that
reaches for `appSettings`, `appRoot` or a C++ type needs either a stub
declared in the test or a refactor to take its inputs as properties — the
existing tests all take the second route.

### On a machine without sound

`SoundEffect` only reaches `Ready` when there is somewhere to send audio. CI
stands up a PulseAudio null sink first:

```bash
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime}"; mkdir -p "$XDG_RUNTIME_DIR"
pulseaudio --start --exit-idle-time=-1
pactl load-module module-null-sink sink_name=dummy
pactl set-default-sink dummy
```

The tests are written to tolerate a completely silent machine as well — the
null sink just lets them take the strict branch.

---

## Conventions

- **Pure where it can be.** Anything that can be decided without a window
  belongs in `app/qml/logic/*.js` and is therefore testable twice — once in
  Node, once in the engine that ships it.
- **Assert the shipped text.** Legend lines, key sequences and alias
  expansions are asserted as literals, so a typo in the UI fails a test
  rather than reaching a screen.
- **No flaky time.** Timers are driven by explicit `wait()`/`tryVerify()`,
  never by fixed sleeps.
- **Offscreen.** Nothing here needs a display; `QT_QPA_PLATFORM=offscreen`
  is the default way to run it.
