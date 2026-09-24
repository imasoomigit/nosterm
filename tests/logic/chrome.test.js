'use strict'
/**
 * Tests for the chrome visibility contract (app/qml/logic/chrome.js):
 * full screen is the pure nostalgic experience, windowed brings the menu.
 *
 * Run with:  node --test tests/logic
 */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const Chrome = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'chrome.js'))

test('nostalgic + windowed: menu and right-click are back, nothing else', () => {
  const v = Chrome.visibility({ nostalgicMode: true, fullscreen: false })
  assert.equal(v.menubar, true, 'leaving full screen brings the menu back')
  assert.equal(v.contextMenu, true, 'right-click works while windowed')
  assert.equal(v.tabBar, false, 'tab strip never under nostalgia')
  assert.equal(v.sizeOverlay, false, 'size overlay never under nostalgia')
  assert.equal(v.anythingVisible, true)
})

test('nostalgic + full screen: not a single piece of chrome', () => {
  const v = Chrome.visibility({ nostalgicMode: true, fullscreen: true })
  assert.deepEqual(v, {
    menubar: false,
    tabBar: false,
    contextMenu: false,
    sizeOverlay: false,
    settingsWindow: true,      // reachable, just never advertised
    anythingVisible: false
  })
  assert.equal(
    Chrome.hasChrome({ nostalgicMode: true, fullscreen: true }), false,
    'full screen must show no chrome at all')
})

test('nostalgic mode is the default when the snapshot says nothing', () => {
  const v = Chrome.visibility({})
  assert.equal(v.menubar, true, 'windowed by default shows the menu')
  assert.equal(v.contextMenu, true)
  assert.equal(Chrome.visibility({ fullscreen: true }).anythingVisible, false)
  assert.equal(Chrome.visibility({ nostalgicMode: false }).tabBar, false,
    'a single tab never shows the tab strip')
})

test('legacy behaviour is untouched when nostalgic mode is off', () => {
  const snapshot = {
    nostalgicMode: false, showMenubar: true, showTerminalSize: false,
    tabCount: 3, isMacOS: false
  }
  // Full screen changes nothing, exactly as it never did before.
  const win = Chrome.visibility({ ...snapshot, fullscreen: false })
  const fs = Chrome.visibility({ ...snapshot, fullscreen: true })
  assert.equal(win.menubar, true)
  assert.equal(fs.menubar, true, 'legacy branch ignores fullscreen')
  assert.equal(win.tabBar, true)
  assert.equal(fs.tabBar, true, 'three tabs show the strip in both modes')
  assert.equal(win.sizeOverlay, false)
  assert.equal(fs.sizeOverlay, false)

  // macOS keeps its menu bar without the legacy switch, elsewhere opt-in.
  assert.equal(Chrome.visibility({ nostalgicMode: false, isMacOS: true }).menubar, true)
  assert.equal(Chrome.visibility({ nostalgicMode: false, isMacOS: false }).menubar, false)
  // The size overlay defaults to on, as it always has.
  assert.equal(Chrome.visibility({ nostalgicMode: false }).sizeOverlay, true)
})
