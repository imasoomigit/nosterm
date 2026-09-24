'use strict'
/**
 * Tests for the colour mode contract (app/qml/logic/colormode.js):
 * monochrome simulation versus true TTY colour, the old chroma slider's
 * meaning, the phosphor presets and the shader variant each mode needs.
 *
 * Run with:  node --test tests/logic
 */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const ColorMode = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'colormode.js'))

test('there are exactly two modes and they are spelled predictably', () => {
  assert.deepEqual(ColorMode.MODES, ['monochrome', 'color'])
  assert.equal(ColorMode.isValid('monochrome'), true)
  assert.equal(ColorMode.isValid('color'), true)
  assert.equal(ColorMode.isValid('colour'), false, 'the British spelling is not a mode')
  assert.equal(ColorMode.isValid(''), false)
  assert.equal(ColorMode.isValid(undefined), false)
  assert.equal(ColorMode.isValid(1), false, 'a mode is a name, never a number')
})

test('anything invalid normalizes to monochrome', () => {
  assert.equal(ColorMode.normalize('color'), 'color')
  assert.equal(ColorMode.normalize('nonsense'), 'monochrome')
  assert.equal(ColorMode.normalize(null), 'monochrome')
  assert.equal(ColorMode.normalize(undefined), 'monochrome')
  // The UI must never be able to ask for a shader that does not exist.
  assert.equal(ColorMode.shaderChromaFlag('nonsense'), 0)
})

test('the mode control round trips through its two indices', () => {
  assert.equal(ColorMode.modeIndex('monochrome'), 0)
  assert.equal(ColorMode.modeIndex('color'), 1)
  assert.equal(ColorMode.modeIndex('garbage'), 0)
  assert.equal(ColorMode.modeAt(0), 'monochrome')
  assert.equal(ColorMode.modeAt(1), 'color')
  assert.equal(ColorMode.modeAt(7), 'monochrome')
  for (const name of ColorMode.MODES) {
    assert.equal(ColorMode.modeAt(ColorMode.modeIndex(name)), name)
  }
})

test('chroma 0 was one phosphor, chroma 1 was the console hue', () => {
  assert.equal(ColorMode.infer(0), 'monochrome')
  assert.equal(ColorMode.infer(0.25), 'monochrome', 'the old default stayed a phosphor look')
  assert.equal(ColorMode.infer(0.49), 'monochrome')
  assert.equal(ColorMode.infer(0.5), 'color', 'half way over reads as a colour profile')
  assert.equal(ColorMode.infer(1), 'color')
})

test('a missing or nonsense chroma infers monochrome', () => {
  assert.equal(ColorMode.infer(undefined), 'monochrome')
  assert.equal(ColorMode.infer(''), 'monochrome')
  assert.equal(ColorMode.infer(null), 'monochrome')
  assert.equal(ColorMode.infer('not a number'), 'monochrome')
  assert.equal(ColorMode.infer(true), 'monochrome')
})

test('the mode selects the shader variant: 1 keeps hues, 0 does not', () => {
  assert.equal(ColorMode.shaderChromaFlag('color'), 1)
  assert.equal(ColorMode.shaderChromaFlag('monochrome'), 0)
})

test('the five phosphor presets are black under a coloured face', () => {
  assert.equal(ColorMode.PHOSPHORS.length, 5)
  const ids = ColorMode.PHOSPHORS.map(p => p.id)
  assert.deepEqual(ids, ['white', 'green', 'blue', 'yellow', 'red'])
  for (const p of ColorMode.PHOSPHORS) {
    assert.equal(p.backgroundColor, '#000000', `${p.name} prints on black`)
    assert.match(p.fontColor, /^#[0-9a-f]{6}$/, `${p.name} carries a plain colour`)
    assert.notEqual(p.fontColor, '#000000', `${p.name} cannot be a black face`)
    assert.match(p.name, /^Black\//, `${p.name} reads as a black/... pair`)
  }
  // The green pair is the IUT mainframe phosphor, and must stay identical
  // to it so the built-in profile and the preset agree.
  assert.equal(ColorMode.PHOSPHORS[1].fontColor, '#3cff7a')
})

test('the names handed to the settings UI match the presets', () => {
  const names = ColorMode.phosphorNames()
  assert.deepEqual(names, ['Black/White', 'Black/Green', 'Black/Blue',
                           'Black/Yellow', 'Black/Red'])
  assert.equal(names.length, ColorMode.PHOSPHORS.length)
  assert.notEqual(ColorMode.phosphorNames(), ColorMode.phosphorNames(),
    'a fresh array each time, so the model cannot alias the table')
})

test('a preset pair is recognised, in either case', () => {
  assert.equal(ColorMode.phosphorIndex('#3cff7a', '#000000'), 1)
  assert.equal(ColorMode.phosphorIndex('#FFFFFF', '#000000'), 0, 'case is ignored')
  assert.equal(ColorMode.phosphorIndex('#ff5b4d', '#000000'), 4)
  assert.equal(ColorMode.phosphorIndex('#ff8100', '#000000'), -1, 'the amber default is custom')
  assert.equal(ColorMode.phosphorIndex('#3cff7a', '#101010'), -1, 'not on black')
})

test('colour spellings that are not plain rgb never match a preset', () => {
  assert.equal(ColorMode.phosphorIndex(undefined, '#000000'), -1)
  assert.equal(ColorMode.phosphorIndex('#3cff7a', undefined), -1)
  assert.equal(ColorMode.phosphorIndex('', ''), -1)
  assert.equal(ColorMode.phosphorIndex('3cff7a', '#000000'), -1, 'no hash, no colour')
  assert.equal(ColorMode.phosphorIndex('#3cf', '#000'), -1, 'too short to be a preset')
  assert.equal(ColorMode.phosphorIndex('#3cff7a', '#00000000'), -1,
    'a transparent background is not the preset pair')
})

test('hex() folds the spellings down to lowercase #rrggbb', () => {
  assert.equal(ColorMode.hex('#3CFF7A'), '#3cff7a')
  assert.equal(ColorMode.hex('  #3cff7a '), '#3cff7a')
  assert.equal(ColorMode.hex('#ff3cff7a'), '#3cff7a', 'ff alpha dropped')
  assert.equal(ColorMode.hex('#80ff0000'), '', 'a real alpha is not an opaque colour')
  assert.equal(ColorMode.hex('#00000000'), '', 'nor is a transparent one')
  assert.equal(ColorMode.hex('#ff000000'), '#000000', 'ff alpha dropped')
  assert.equal(ColorMode.hex(null), '')
  assert.equal(ColorMode.hex(42), '')
  assert.equal(ColorMode.hex('#12345'), '')
})
