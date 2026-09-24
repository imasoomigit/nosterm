'use strict'
/** Tests for audible feedback gating (app/qml/logic/sound.js). */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const Sound = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'sound.js'))

test('nothing makes a noise unless the master switch is on', () => {
  assert.equal(Sound.audible({}), false)
  assert.equal(Sound.audible(undefined), false)
  assert.equal(Sound.audible({ keyClick: true, bell: true }), false)
  assert.equal(Sound.audible({ audioEnabled: true }), true)
})

test('key click requires both the master switch and the click switch', () => {
  const on = { audioEnabled: true, keyClick: true }
  assert.equal(Sound.shouldClick(on, {}), true)
  assert.equal(Sound.shouldClick({ audioEnabled: true, keyClick: false }, {}), false)
  assert.equal(Sound.shouldClick({ audioEnabled: false, keyClick: true }, {}), false)
  assert.equal(Sound.shouldClick(undefined, {}), false)
})

test('auto-repeat does not machine-gun the click', () => {
  const on = { audioEnabled: true, keyClick: true }
  assert.equal(Sound.shouldClick(on, { isAutoRepeat: true }), false)
  assert.equal(Sound.shouldClick(on, { isAutoRepeat: false }), true)
})

test('a paste does not click per character', () => {
  const on = { audioEnabled: true, keyClick: true }
  assert.equal(Sound.shouldClick(on, { fromPaste: true }), false)
})

test('modifier-only presses are silent', () => {
  const on = { audioEnabled: true, keyClick: true }
  assert.equal(Sound.shouldClick(on, { isModifierOnly: true }), false)
})

test('bell is gated independently of the key click', () => {
  assert.equal(Sound.shouldBell({ audioEnabled: true, bell: true }), true)
  assert.equal(Sound.shouldBell({ audioEnabled: true, bell: false }), false)
  assert.equal(Sound.shouldBell({ audioEnabled: false, bell: true }), false)
  assert.equal(Sound.shouldBell({ keyClick: true }), false)
})

test('volume is clamped to 0..1', () => {
  assert.equal(Sound.volume(0.5), 0.5)
  assert.equal(Sound.volume(-3), 0)
  assert.equal(Sound.volume(17), 1)
  assert.equal(Sound.volume('x'), 0.5, 'falls back to the default')
  assert.equal(Sound.volume('x', 0.25), 0.25)
  assert.equal(Sound.volume(NaN), 0.5)
  assert.equal(Sound.volume(null), 0.5)
  assert.equal(Sound.volume(undefined), 0.5)
})

test('arming the key click opens the master gate so it is audible', () => {
  // Turning it ON must flip both switches, or the click stays silent.
  assert.deepEqual(
    Sound.toggleKeyClick({ keyClick: false, audioEnabled: false }),
    { keyClick: true, audioEnabled: true })
  // Turning it OFF leaves the master alone: the bell has its own switch.
  assert.deepEqual(
    Sound.toggleKeyClick({ keyClick: true, audioEnabled: true }),
    { keyClick: false, audioEnabled: true })
  assert.deepEqual(
    Sound.toggleKeyClick({ keyClick: true, audioEnabled: false }),
    { keyClick: false, audioEnabled: false })
  // Tolerant of missing state.
  assert.deepEqual(Sound.toggleKeyClick(undefined),
    { keyClick: true, audioEnabled: true })
})

test('the keyboard tick offers the bundled depths, nothing else', () => {
  assert.equal(Sound.isClickSound('tick'), true)
  assert.equal(Sound.isClickSound('deep'), true)
  assert.equal(Sound.isClickSound('deeper'), true)
  for (const bad of ['off', 'TICK', '', null, undefined, 7])
    assert.equal(Sound.isClickSound(bad), false, String(bad))
  assert.deepEqual([...Sound.CLICK_SOUNDS], ['tick', 'deep', 'deeper'])
})

test('every tick setting resolves to a bundled sample', () => {
  assert.equal(Sound.sampleSource('tick'), 'qrc:/sounds/keyclick.wav')
  assert.equal(Sound.sampleSource('deep'), 'qrc:/sounds/keyclick-deep.wav')
  assert.equal(Sound.sampleSource('deeper'), 'qrc:/sounds/keyclick-deeper.wav')
  // Settings written before this existed (or junk) keep the old click.
  assert.equal(Sound.sampleSource(undefined), 'qrc:/sounds/keyclick.wav')
  assert.equal(Sound.sampleSource(''), 'qrc:/sounds/keyclick.wav')
  assert.equal(Sound.sampleSource(42), 'qrc:/sounds/keyclick.wav')
})
