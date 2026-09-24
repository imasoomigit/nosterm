'use strict'
/**
 * Tests for platform-aware key sequences (app/qml/logic/platform.js).
 *
 * These assert the "same functionality, exactly the same as the OS" rule:
 * each function must land on the sequence that is conventional for that OS.
 */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const Platform = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'platform.js'))

test('normalizeOs buckets every spelling Qt can produce', () => {
  assert.equal(Platform.normalizeOs('osx'), 'mac')
  assert.equal(Platform.normalizeOs('OSX'), 'mac')
  assert.equal(Platform.normalizeOs('macos'), 'mac')
  assert.equal(Platform.normalizeOs('darwin'), 'mac')
  assert.equal(Platform.normalizeOs('win32'), 'windows')
  assert.equal(Platform.normalizeOs('Windows'), 'windows')
  assert.equal(Platform.normalizeOs('win64'), 'windows')
  assert.equal(Platform.normalizeOs('x11'), 'linux')
  assert.equal(Platform.normalizeOs('wayland'), 'linux')
  assert.equal(Platform.normalizeOs('linux'), 'linux')
  assert.equal(Platform.normalizeOs('freebsd'), 'linux')
  assert.equal(Platform.normalizeOs(undefined), 'linux')
  assert.equal(Platform.normalizeOs(null), 'linux')
})

test('isMac', () => {
  assert.equal(Platform.isMac('osx'), true)
  assert.equal(Platform.isMac('x11'), false)
})

test('macOS uses the native Cmd based conventions', () => {
  const s = Platform.sequences('osx')
  assert.equal(s.newWindow, 'Meta+N')       // Cmd+N
  assert.equal(s.newTab, 'Meta+T')          // Cmd+T
  assert.equal(s.closeTab, 'Meta+W')        // Cmd+W
  assert.equal(s.closeWindow, 'Meta+Shift+W')
  assert.equal(s.nextWindow, 'Meta+`')      // Cmd+` is the native binding
  assert.equal(s.prevWindow, 'Meta+Shift+`')
  assert.equal(s.settings, 'Meta+,')        // Cmd+, is the convention
  assert.equal(s.quit, 'StandardKey.Quit')  // Cmd+Q
})

test('windows uses the terminal/browser conventions', () => {
  const s = Platform.sequences('win32')
  assert.equal(s.newWindow, 'Ctrl+Shift+N')
  assert.equal(s.newTab, 'Ctrl+Shift+T')
  assert.equal(s.closeTab, 'Ctrl+W')
  assert.equal(s.closeWindow, 'Ctrl+Shift+W')
  assert.equal(s.nextWindow, 'Alt+`')
  assert.equal(s.settings, 'Ctrl+,')
  assert.equal(s.quit, 'Ctrl+Shift+Q')
})

test('linux is identical to windows', () => {
  assert.deepEqual(Platform.sequences('x11'), Platform.sequences('win32'))
  assert.deepEqual(Platform.sequences('wayland'), Platform.sequences('win32'))
})

test('linux Alt+` matches GNOME/KDE "windows of this application"', () => {
  // GNOME default for switch-group / switch-windows-of-app is Alt+Above_Tab.
  assert.equal(Platform.sequence('linux', 'nextWindow'), 'Alt+`')
  assert.equal(Platform.sequence('linux', 'prevWindow'), 'Alt+Shift+`')
})

test('closeTab and closeWindow never collide on any platform', () => {
  for (const os of ['osx', 'win32', 'x11', 'wayland']) {
    const s = Platform.sequences(os)
    assert.notEqual(s.closeTab, s.closeWindow, `collision on ${os}`)
    assert.notEqual(s.newTab, s.newWindow, `collision on ${os}`)
    assert.notEqual(s.nextWindow, s.prevWindow, `collision on ${os}`)
  }
})

test('quit never collides with closeTab on any platform', () => {
  for (const os of ['osx', 'win32', 'x11']) {
    const s = Platform.sequences(os)
    assert.notEqual(s.quit, s.closeTab, `quit collides with closeTab on ${os}`)
    assert.notEqual(s.quit, s.closeWindow, `quit collides with closeWindow on ${os}`)
  }
})

test('every platform exposes the same set of functions', () => {
  const names = Object.keys(Platform.sequences('osx'))
  for (const os of ['win32', 'x11']) {
    assert.deepEqual(Object.keys(Platform.sequences(os)).sort(), names.sort())
  }
  for (const n of names) {
    assert.ok(Platform.sequence('osx', n).length > 0, `mac ${n} is set`)
    assert.ok(Platform.sequence('x11', n).length > 0, `linux ${n} is set`)
  }
})

test('sequence() rejects unknown names instead of inventing bindings', () => {
  assert.equal(Platform.sequence('osx', 'doesNotExist'), '')
  assert.equal(Platform.sequence('osx', undefined), '')
})

test('usableSequences filters out empty entries', () => {
  const out = Platform.usableSequences('osx', ['newWindow', 'nope', 'quit'])
  assert.deepEqual(Object.keys(out).sort(), ['newWindow', 'quit'])
  assert.equal(out.newWindow, 'Meta+N')
})

test('zoom in: the standard binding plus every physical spelling', () => {
  // The menu shows the conventional binding...
  assert.equal(Platform.sequence('mac', 'zoomIn'), 'StandardKey.ZoomIn')
  assert.equal(Platform.sequence('x11', 'zoomIn'), 'Ctrl++')

  // ...while the window binds what a real keyboard actually sends.
  // "+" on a US layout = Ctrl+Shift+'+' , "=" = Ctrl+'=' .  mac gets the
  // same treatment with Cmd.
  assert.deepEqual(Platform.alternates('x11', 'zoomIn'), ['Ctrl+Shift++', 'Ctrl+='])
  assert.deepEqual(Platform.alternates('wayland', 'zoomIn'), ['Ctrl+Shift++', 'Ctrl+='])
  assert.deepEqual(Platform.alternates('osx', 'zoomIn'), ['Meta+Shift++', 'Meta+='])
})

test('zoomSpellings: every key that must hold a live zoom binding', () => {
  // The floor under the menu Action: the standard spelling included, so
  // the key still works when the Action's window context cannot resolve
  // (full screen), plus every physical spelling of "+" and "=".
  assert.deepEqual(Platform.zoomSpellings('x11', 'zoomIn'),
    ['Ctrl++', 'Ctrl+Shift++', 'Ctrl+='])
  assert.deepEqual(Platform.zoomSpellings('osx', 'zoomIn'),
    ['Meta++', 'Meta+Shift++', 'Meta+=', 'Ctrl++', 'Ctrl+Shift++', 'Ctrl+='])
  assert.deepEqual(Platform.zoomSpellings('x11', 'zoomOut'), ['Ctrl+-'])
  assert.deepEqual(Platform.zoomSpellings('osx', 'zoomOut'), ['Meta+-', 'Ctrl+-'])
  assert.deepEqual(Platform.zoomSpellings('x11', 'newWindow'), [])
  assert.deepEqual(Platform.zoomSpellings('x11', 'doesNotExist'), [])

  for (const os of ['osx', 'win32', 'x11']) {
    const spellings = Platform.zoomSpellings(os, 'zoomIn')
    assert.equal(new Set(spellings).size, spellings.length,
      `${os} spellings unique`)
    // No two spellings can match one keypress: each uses a different key
    // or a different modifier set ("Ctrl++" vs "Ctrl+Shift++" etc.).
    for (const s of spellings)
      assert.ok(s.startsWith('Ctrl+') || s.startsWith('Meta+'),
        `${os} spelling is a plain key sequence`)
  }

  // macOS carries the Ctrl family on top of Cmd (the plain Ctrl chord is
  // the one macOS itself never claims), and that family is exactly the
  // Linux floor -- one code path covers both.
  const macCtrl = Platform.zoomSpellings('osx', 'zoomIn')
    .filter(s => s.startsWith('Ctrl+'))
  assert.deepEqual(macCtrl, Platform.zoomSpellings('x11', 'zoomIn'))
  assert.deepEqual(Platform.zoomSpellings('osx', 'zoomOut').filter(
    s => s.startsWith('Ctrl+')), Platform.zoomSpellings('x11', 'zoomOut'))
})

test('zoom alternates never duplicate the primary binding', () => {
  for (const os of ['osx', 'win32', 'x11']) {
    const primary = Platform.sequence(os, 'zoomIn')
    const alts = Platform.alternates(os, 'zoomIn')
    assert.ok(alts.length > 0, `${os} has alternates`)
    assert.ok(!alts.includes(primary), `${os} primary not repeated`)
    // And no two spellings can match one keypress: every alternate uses
    // either a different key or a different modifier set.
    assert.equal(new Set(alts).size, alts.length, `${os} alternates unique`)
  }
})

test('only zoomIn carries alternates', () => {
  assert.deepEqual(Platform.alternates('x11', 'zoomOut'), [])
  assert.deepEqual(Platform.alternates('x11', 'newWindow'), [])
  assert.deepEqual(Platform.alternates('x11', 'doesNotExist'), [])
})
