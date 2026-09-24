'use strict'
/** Tests for window cycling arithmetic (app/qml/logic/windows.js). */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const Windows = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'windows.js'))

test('wrap normalises into range', () => {
  assert.equal(Windows.wrap(0, 3), 0)
  assert.equal(Windows.wrap(2, 3), 2)
  assert.equal(Windows.wrap(3, 3), 0)
  assert.equal(Windows.wrap(-1, 3), 2)
  assert.equal(Windows.wrap(-4, 3), 2)
  assert.equal(Windows.wrap(7, 3), 1)
})

test('wrap returns -1 when there is nothing to wrap', () => {
  assert.equal(Windows.wrap(0, 0), -1)
  assert.equal(Windows.wrap(5, 0), -1)
  assert.equal(Windows.wrap(-1, -2), -1)
})

test('wrap treats non numeric input as index 0', () => {
  assert.equal(Windows.wrap(undefined, 4), 0)
  assert.equal(Windows.wrap(NaN, 4), 0)
  assert.equal(Windows.wrap('junk', 4), 0)
  assert.equal(Windows.wrap(2.9, 4), 2, 'truncates rather than rounds up')
})

test('cycling forwards wraps around the end', () => {
  assert.equal(Windows.cycleIndex(0, 3, 1), 1)
  assert.equal(Windows.cycleIndex(1, 3, 1), 2)
  assert.equal(Windows.cycleIndex(2, 3, 1), 0, 'last window cycles back to first')
  assert.equal(Windows.cycleIndex(0, 3, 2), 2)
  assert.equal(Windows.cycleIndex(0, 3, 3), 0, 'a full lap lands where it started')
})

test('cycling backwards wraps around the start', () => {
  assert.equal(Windows.cycleIndex(0, 3, -1), 2)
  assert.equal(Windows.cycleIndex(2, 3, -1), 1)
  assert.equal(Windows.cycleIndex(1, 3, -2), 2)
})

test('cycling with one window stays put', () => {
  assert.equal(Windows.cycleIndex(0, 1, 1), 0)
  assert.equal(Windows.cycleIndex(0, 1, -1), 0)
})

test('cycling with no windows is a no-op', () => {
  assert.equal(Windows.cycleIndex(0, 0, 1), -1)
  assert.equal(Windows.cycleIndex(2, 0, -1), -1)
})

test('an unknown active index is treated as the first window', () => {
  assert.equal(Windows.cycleIndex(-5, 3, 1), 1)
  assert.equal(Windows.cycleIndex(NaN, 3, 1), 1)
  assert.equal(Windows.cycleIndex(undefined, 3, -1), 2)
})

test('shouldCycle only fires when it would actually change window', () => {
  assert.equal(Windows.shouldCycle(0, 1), false, 'single window: nothing to do')
  assert.equal(Windows.shouldCycle(0, 0), false, 'no windows')
  assert.equal(Windows.shouldCycle(0, 2), true)
  assert.equal(Windows.shouldCycle(1, 2), true)
})

test('closing the active window picks the successor', () => {
  // 4 windows, close index 1 while 1 is active -> active becomes 1 (the old 2).
  assert.equal(Windows.indexAfterRemoval(1, 1, 4), 1)
  // Closing a window before the active one shifts it down by one.
  assert.equal(Windows.indexAfterRemoval(3, 0, 4), 2)
  // Closing the active first window keeps the active index pointing forward.
  assert.equal(Windows.indexAfterRemoval(0, 0, 4), 0)
  // Closing the last window pulls the active index back.
  assert.equal(Windows.indexAfterRemoval(3, 3, 4), 2)
})

test('closing the only window leaves nothing active', () => {
  assert.equal(Windows.indexAfterRemoval(0, 0, 1), -1)
})

test('closing when there are no windows is a no-op', () => {
  assert.equal(Windows.indexAfterRemoval(0, 0, 0), -1)
})

test('full screen carries across creation and cycling, never demotes', () => {
  assert.equal(Windows.inheritFullscreen(true, false), true, 'born from full screen')
  assert.equal(Windows.inheritFullscreen(false, true), true, 'target already full screen')
  assert.equal(Windows.inheritFullscreen(true, true), true)
  assert.equal(Windows.inheritFullscreen(false, false), false, 'windowed stays windowed')
})

test('new window with a profile named opens on that profile', () => {
  // The "New Window with Profile" submenu names one, and it wins outright.
  assert.equal(Windows.newWindowLoadName('IUT-MarkazMohasebat', ''), 'IUT-MarkazMohasebat')
  assert.equal(Windows.newWindowLoadName('IUT-MarkazMohasebat', 'Deep Blue'), 'IUT-MarkazMohasebat')
})

test('plain new window (no argument) falls back to the default profile', () => {
  assert.equal(Windows.newWindowLoadName(undefined, 'Deep Blue'), 'Deep Blue')
  assert.equal(Windows.newWindowLoadName(undefined, undefined), '')
})

test('with no default configured a plain new window loads nothing', () => {
  // Never guess at a factory look the user never chose: carry on with
  // what is already on screen.
  assert.equal(Windows.newWindowLoadName(undefined, ''), '')
  assert.equal(Windows.newWindowLoadName(undefined, null), '')
  assert.equal(Windows.newWindowLoadName(undefined, 42), '')
})

test('an empty request means load nothing, so startup keeps its choice', () => {
  // The first window asks with "", and --profile / the default / the stored
  // snapshot has already been applied by then.
  assert.equal(Windows.newWindowLoadName('', 'Deep Blue'), '')
  assert.equal(Windows.newWindowLoadName(null, 'Deep Blue'), '')
  assert.equal(Windows.newWindowLoadName(42, 'Deep Blue'), '')
  assert.equal(Windows.newWindowLoadName({}, 'Deep Blue'), '')
})
