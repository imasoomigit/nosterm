'use strict'
/**
 * Tests for retro settings defaults + tolerant merging
 * (app/qml/logic/defaults.js) and for the chrome visibility rules.
 */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const Defaults = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'defaults.js'))

test('nostalgic mode is on by default: no chrome at all', () => {
  const d = Defaults.defaults()
  assert.equal(d.nostalgicMode, true, 'zero-chrome is the default experience')
  assert.equal(d.showPfKeys, false, 'PF bar is opt-in')
  assert.equal(d.audioEnabled, false, 'key click is opt-in')
  assert.equal(d.keyClickSound, 'tick', 'the factory tick is the pick')
  assert.equal(d.highlightActiveLine, false, 'line highlight is opt-in')
  assert.equal(d.cursorStyle, 'block')
})

test('merge keeps defaults for missing keys', () => {
  assert.deepEqual(Defaults.merge(undefined), Defaults.defaults())
  assert.deepEqual(Defaults.merge(null), Defaults.defaults())
  assert.deepEqual(Defaults.merge('a string'), Defaults.defaults())
  assert.deepEqual(Defaults.merge({}), Defaults.defaults())
  assert.deepEqual(Defaults.merge({ nonsense: 42 }), Defaults.defaults())
})

test('merge accepts valid values', () => {
  const out = Defaults.merge({
    nostalgicMode: false,
    showPfKeys: true,
    pfKeys: '[{"action":"newWindow"}]',
    audioEnabled: true,
    keyClick: false,
    bell: false,
    keyClickVolume: 0.75,
    keyClickSound: 'deeper',
    bellVolume: 0.25,
    highlightActiveLine: true,
    activeLineOpacity: 0.4,
    cursorStyle: 'half'
  })
  assert.equal(out.nostalgicMode, false)
  assert.equal(out.showPfKeys, true)
  assert.equal(out.pfKeys, '[{"action":"newWindow"}]')
  assert.equal(out.audioEnabled, true)
  assert.equal(out.keyClick, false)
  assert.equal(out.bell, false)
  assert.equal(out.keyClickVolume, 0.75)
  assert.equal(out.keyClickSound, 'deeper')
  assert.equal(out.bellVolume, 0.25)
  assert.equal(out.highlightActiveLine, true)
  assert.equal(out.activeLineOpacity, 0.4)
  assert.equal(out.cursorStyle, 'half')
})

test('merge repairs wrong types instead of trusting them', () => {
  const out = Defaults.merge({
    nostalgicMode: 'yes',
    showPfKeys: 1,
    pfKeys: 42,
    keyClickVolume: 'loud',
    keyClickSound: 'loud',
    bellVolume: 9000,
    activeLineOpacity: -5,
    cursorStyle: 'rainbow'
  })
  assert.equal(out.nostalgicMode, Defaults.defaults().nostalgicMode, 'non-boolean ignored')
  assert.equal(out.showPfKeys, Defaults.defaults().showPfKeys, 'non-boolean ignored')
  assert.equal(out.pfKeys, Defaults.defaults().pfKeys, 'non-string ignored')
  assert.equal(out.keyClickVolume, 0.5, 'unparseable volume falls back')
  assert.equal(out.keyClickSound, 'tick', 'unknown sample rejected')
  assert.equal(out.bellVolume, 1, 'clamped to 1')
  assert.equal(out.activeLineOpacity, 0, 'clamped to 0')
  assert.equal(out.cursorStyle, 'block', 'unknown style rejected')
})

test('volumes are clamped to the 0..1 range', () => {
  assert.equal(Defaults.merge({ keyClickVolume: -1 }).keyClickVolume, 0)
  assert.equal(Defaults.merge({ keyClickVolume: 2 }).keyClickVolume, 1)
  assert.equal(Defaults.clampNumber(5, 0.5, 0, 1), 1)
  assert.equal(Defaults.clampNumber('x', 0.5, 0, 1), 0.5)
})

test('serialize/parse round trips', () => {
  const settings = {
    nostalgicMode: false,
    showPfKeys: true,
    pfKeys: '[]',
    audioEnabled: true,
    keyClickVolume: 0.9,
    cursorStyle: 'half',
    legendTextColor: '#00FF7F',
    legendArrowBgColor: '#11223344'
  }
  const restored = Defaults.parse(Defaults.serialize(settings))
  assert.deepEqual(restored, Defaults.merge(settings))
})

test('parse tolerates corrupt stored values', () => {
  assert.deepEqual(Defaults.parse(undefined), Defaults.defaults())
  assert.deepEqual(Defaults.parse(''), Defaults.defaults())
  assert.deepEqual(Defaults.parse('{{{'), Defaults.defaults())
  assert.deepEqual(Defaults.parse('[1,2,3]'), Defaults.defaults())
})

test('defaults() returns a fresh object each call', () => {
  const a = Defaults.defaults()
  a.nostalgicMode = false
  assert.equal(Defaults.defaults().nostalgicMode, true, 'no shared mutable state')
})

test('legend colours default to the phosphor and clear glass', () => {
  const d = Defaults.defaults()
  assert.equal(d.legendTextColor, '', 'text follows the phosphor')
  assert.equal(d.legendArrowColor, '', 'arrow follows the phosphor')
  assert.equal(d.legendTextBgColor, '#00000000', 'no chip behind the words')
  assert.equal(d.legendArrowBgColor, '#00000000', 'no chip behind the arrow')
})

test('merge keeps valid legend colours, "" included', () => {
  const out = Defaults.merge({
    legendTextColor: '#00FF7F',
    legendTextBgColor: '#10203040',
    legendArrowColor: '',
    legendArrowBgColor: '#abc'
  })
  assert.equal(out.legendTextColor, '#00FF7F')
  assert.equal(out.legendTextBgColor, '#10203040')
  assert.equal(out.legendArrowColor, '')
  assert.equal(out.legendArrowBgColor, '#abc')
})

test('merge drops nonsense legend colours', () => {
  const d = Defaults.defaults()
  const out = Defaults.merge({
    legendTextColor: 'green',
    legendTextBgColor: 42,
    legendArrowColor: '#12345',
    legendArrowBgColor: 'transparent'
  })
  assert.equal(out.legendTextColor, d.legendTextColor, 'names are not colours')
  assert.equal(out.legendTextBgColor, d.legendTextBgColor)
  assert.equal(out.legendArrowColor, d.legendArrowColor, 'five hex digits? no')
  assert.equal(out.legendArrowBgColor, d.legendArrowBgColor)
  // Backgrounds may not be "": transparent is spelled #00000000.
  assert.equal(Defaults.merge({ legendTextBgColor: '' }).legendTextBgColor,
               d.legendTextBgColor)
})

test('profiles carry the legend colours; old ones leave them alone', () => {
  // A profile recorded today describes all seventeen extras, colours first.
  const saved = Defaults.pickIbmExtras({
    showPfKeys: true,
    legendTextColor: '#00FF7F',
    legendTextBgColor: '#11223344',
    legendArrowColor: '#FF8100',
    legendArrowBgColor: '#00000000'
  })
  assert.equal(saved.legendTextColor, '#00FF7F')
  assert.equal(saved.legendTextBgColor, '#11223344')
  assert.equal(saved.legendArrowColor, '#FF8100')
  assert.equal(saved.legendArrowBgColor, '#00000000')
  // Garbage never reaches a profile: it becomes the default instead.
  assert.equal(Defaults.pickIbmExtras({ legendTextColor: 'chartreuse' })
                 .legendTextColor, '')

  // An old visual-only profile names no colours: absent, so nothing applies.
  const old = Defaults.profileExtras({ showPfKeys: true })
  assert.equal('legendTextColor' in old, false)
  assert.equal('legendArrowBgColor' in old, false)

  // A new one specifies them -- valid ones only.
  const fresh = Defaults.profileExtras({
    legendTextColor: '#00FF7F',
    legendArrowColor: 17
  })
  assert.equal(fresh.legendTextColor, '#00FF7F')
  assert.equal('legendArrowColor' in fresh, false, 'wrong type dropped')
})

test('isHexColor / isFgColor spell out what a colour may be', () => {
  for (const ok of ['#abc', '#AABBCC', '#01234567'])
    assert.equal(Defaults.isHexColor(ok), true, ok)
  for (const bad of ['', 'red', '#ab', '#abcde', '#gggggg', 42, null])
    assert.equal(Defaults.isHexColor(bad), false, String(bad))
  assert.equal(Defaults.isFgColor(''), true, '"" means the phosphor')
  assert.equal(Defaults.isFgColor('#abc'), true)
})

test('legend type: the screen face and size unless dressed by hand', () => {
  const d = Defaults.defaults()
  assert.equal(d.legendFontFamily, '', 'follows the screen font')
  assert.equal(d.legendFontScale, 1.0, 'the very size of the screen font')

  // A family may be any string ("" is meaningful); a scale is clamped
  // into the slider's range, unparseable values keep the default.
  assert.equal(Defaults.merge({ legendFontFamily: 'Terminus' })
                 .legendFontFamily, 'Terminus')
  assert.equal(Defaults.merge({ legendFontFamily: 42 }).legendFontFamily, '')
  assert.equal(Defaults.merge({ legendFontScale: 1.5 }).legendFontScale, 1.5)
  assert.equal(Defaults.merge({ legendFontScale: 99 }).legendFontScale, 3)
  assert.equal(Defaults.merge({ legendFontScale: -1 }).legendFontScale, 0.4)
  assert.equal(Defaults.merge({ legendFontScale: 'loud' }).legendFontScale, 1)

  // Save side records both, garbage repaired; load side leaves the
  // profiles of old entirely alone.
  const saved = Defaults.pickIbmExtras({
    legendFontFamily: 'Terminus', legendFontScale: 0.8 })
  assert.equal(saved.legendFontFamily, 'Terminus')
  assert.equal(saved.legendFontScale, 0.8)
  assert.equal(Defaults.pickIbmExtras({ legendFontScale: 'x' })
                 .legendFontScale, 1.0)

  const old = Defaults.profileExtras({ showPfKeys: true })
  assert.equal('legendFontFamily' in old, false)
  assert.equal('legendFontScale' in old, false)
  const fresh = Defaults.profileExtras({
    legendFontFamily: 'Terminus', legendFontScale: 1.2 })
  assert.equal(fresh.legendFontFamily, 'Terminus')
  assert.equal(fresh.legendFontScale, 1.2)
  assert.equal('legendFontScale' in Defaults.profileExtras(
    { legendFontScale: 'x' }), false, 'wrong type dropped')
})

test('the keyboard tick sound rides along with profiles', () => {
  // The three bundled depths are the only valid picks; anything else
  // (including nothing at all) becomes the factory tick.
  assert.equal(Defaults.defaults().keyClickSound, 'tick')
  assert.equal(Defaults.merge({ keyClickSound: 'deep' }).keyClickSound, 'deep')
  assert.equal(Defaults.merge({ keyClickSound: 'deeper' }).keyClickSound, 'deeper')
  assert.equal(Defaults.merge({ keyClickSound: 'loud' }).keyClickSound, 'tick',
    'unknown sample rejected')
  assert.equal(Defaults.merge({ keyClickSound: 42 }).keyClickSound, 'tick')

  // Save side: always recorded, garbage repaired.
  assert.equal(Defaults.pickIbmExtras({ keyClickSound: 'deep' }).keyClickSound,
    'deep')
  assert.equal(Defaults.pickIbmExtras({ keyClickSound: 'hiss' }).keyClickSound,
    'tick')

  // Load side: old profiles carry no such field and leave it alone.
  const old = Defaults.profileExtras({ showPfKeys: true })
  assert.equal('keyClickSound' in old, false)
  assert.equal(Defaults.profileExtras({ keyClickSound: 'deeper' }).keyClickSound,
    'deeper')
  assert.equal('keyClickSound' in Defaults.profileExtras({ keyClickSound: 'loud' }),
    false, 'wrong sample dropped, not trusted')
})
