'use strict'
/**
 * Tests for the profile-carried IBM extras (defaults.js) and the built-in
 * "IUT-MarkazMohasebat" mainframe profile (ibmprofile.js).
 *
 * Run with:  node --test tests/logic
 */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const Defaults = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'defaults.js'))
const IbmProfile = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'ibmprofile.js'))
const PfKeys = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'pfkeys.js'))
const Profiles = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'profiles.js'))

const EXTRAS = ['showPfKeys', 'pfKeys', 'audioEnabled', 'keyClick',
  'keyClickVolume', 'keyClickSound', 'bell', 'bellVolume',
  'highlightActiveLine', 'activeLineOpacity', 'cursorStyle',
  'legendTextColor', 'legendTextBgColor', 'legendArrowColor',
  'legendArrowBgColor', 'legendFontFamily', 'legendFontScale']

test('the save side always records the full IBM set', () => {
  const saved = Defaults.pickIbmExtras({
    showPfKeys: true, keyClickVolume: 0.7, cursorStyle: 'half'
  })
  assert.deepEqual(Object.keys(saved).sort(), [...EXTRAS].sort(),
    'a profile recorded today describes the whole mainframe half')
  assert.equal(saved.showPfKeys, true)
  assert.equal(saved.keyClickVolume, 0.7)
  assert.equal(saved.cursorStyle, 'half')

  // Hostile input never leaks through.
  const bad = Defaults.pickIbmExtras({
    showPfKeys: 'yes', keyClickVolume: 99, cursorStyle: 'fancy'
  })
  assert.equal(bad.showPfKeys, false)
  assert.equal(bad.keyClickVolume, 1)
  assert.equal(bad.cursorStyle, 'block')

  // Chrome is not a profile field, on either side.
  assert.equal('nostalgicMode' in saved, false)
  assert.equal('nostalgicMode' in Defaults.profileExtras({ nostalgicMode: true }), false)
})

test('the load side keeps absent fields absent so old profiles stay polite', () => {
  const partial = Defaults.profileExtras({ showPfKeys: true, keyClickVolume: 2 })
  assert.equal(partial.showPfKeys, true)
  assert.equal(partial.keyClickVolume, 1, 'clamped, but present')
  assert.equal('cursorStyle' in partial, false, 'absent = keep the current value')
  assert.equal('audioEnabled' in partial, false)

  assert.deepEqual(Defaults.profileExtras(null), {})
  assert.deepEqual(Defaults.profileExtras('nope'), {})

  // Wrong types are dropped, not trusted.
  const hostile = Defaults.profileExtras({ pfKeys: 42, bell: 'loud' })
  assert.equal('pfKeys' in hostile, false)
  assert.equal('bell' in hostile, false)
})

test('mainframeKeys passes the factory panel through untouched', () => {
  const defs = PfKeys.defaultAssignments()
  const keys = IbmProfile.mainframeKeys(defs)
  assert.equal(keys.length, PfKeys.KEY_COUNT)
  // The factory panel IS the mainframe panel: window and menu functions,
  // no shell commands (FILEL / XEDIT live in the alias block instead).
  assert.deepEqual(keys, defs)
  // Copy, not alias: mutating the result must not touch the defaults.
  keys[4].action = 'sendText'
  assert.equal(defs[4].action, 'prevWindow')
  assert.equal(defs[5].action, 'splitHorizontal')
  assert.equal(keys[12].action, 'interrupt', 'PA1 = Attention survives')
  // The helper is defensive about short or missing input.
  assert.deepEqual(IbmProfile.mainframeKeys(null), [])
})

test('the IUT profile is green-on-black IBM with everything on', () => {
  const p = IbmProfile.mainframeProfile(PfKeys.serialize(
    IbmProfile.mainframeKeys(PfKeys.defaultAssignments())))

  // Look: the IBM 3278 Reborn station.
  assert.equal(p.fontColor, '#3cff7a', 'green phosphor')
  assert.equal(p.backgroundColor, '#000000', 'black background')
  assert.equal(p.fontName, 'IBM_3278')
  assert.equal(p.screenCurvature, 0, 'flat glass')
  // Exactly like the 370 terminal: a blinking block cursor.
  assert.equal(p.blinkingCursor, true)
  assert.equal(p.cursorStyle, 'block')

  // Everything IBM, switched on at once.
  for (const flag of ['showPfKeys', 'audioEnabled', 'keyClick', 'bell',
    'highlightActiveLine']) {
    assert.equal(p[flag], true, `${flag} must be on`)
  }
  assert.equal(p.keyClickSound, 'tick', 'the factory tick is recorded too')
  for (const key of EXTRAS)
    assert.ok(key in p, `${key} missing from the IUT profile`)

  // The PF assignments stored in the profile carry the factory panel:
  // window and menu functions (shell commands live in the alias block).
  const slots = PfKeys.parse(p.pfKeys)
  assert.equal(slots[4].action, 'prevWindow')
  assert.equal(slots[5].action, 'splitHorizontal')
  assert.equal(slots[12].action, 'interrupt')
})

// THE SAVE / DEFAULT / RESET BOOKKEEPING (logic/profiles.js) ////////////////

const LIST = [
  { text: 'Amber', obj_string: '{"a":1}', builtin: true },
  { text: 'Green', obj_string: '{"a":2}', builtin: true },
  { text: 'Mine', obj_string: '{"a":3}', builtin: false }
]

test('Save writes to the active profile, else the default, else asks once', () => {
  // A profile is active (it was loaded) -> silently overwrite it.
  assert.equal(Profiles.saveTargetName(LIST, 'Mine', 'Amber'), 'Mine')
  // Nothing active but a default exists -> that is the target too.
  assert.equal(Profiles.saveTargetName(LIST, '', 'Amber'), 'Amber')
  // An active name whose profile was removed falls back to the default.
  assert.equal(Profiles.saveTargetName(LIST, 'Ghost', 'Amber'), 'Amber')
  // Neither -> "" is the one case where the name prompt may appear,
  // and only once: the name it collects becomes the active profile.
  assert.equal(Profiles.saveTargetName(LIST, '', ''), '')
  assert.equal(Profiles.saveTargetName(LIST, 'Ghost', 'Ghost2'), '')
})

test('the app opens on --profile, then the default, then the snapshot', () => {
  assert.equal(Profiles.startupLoadName(LIST, 'Mine', 'Green'), 'Mine')
  assert.equal(Profiles.startupLoadName(LIST, '', 'Green'), 'Green')
  assert.equal(Profiles.startupLoadName(LIST, 'Ghost', 'Green'), 'Green',
    'a bad --profile name falls back to the default')
  assert.equal(Profiles.startupLoadName(LIST, '', ''), '',
    'no profile at all = open on the stored snapshot')
})

test('the active profile survives restarts as the Save target', () => {
  assert.equal(Profiles.startupActiveName(LIST, 'Mine', 'Green', 'Amber'), 'Mine')
  assert.equal(Profiles.startupActiveName(LIST, '', 'Green', 'Amber'), 'Green',
    'the default that was loaded is the active one')
  assert.equal(Profiles.startupActiveName(LIST, '', '', 'Mine'), 'Mine',
    'loaded last time stays the target (its values are in the snapshot)')
  assert.equal(Profiles.startupActiveName(LIST, '', '', 'Ghost'), '',
    'a removed profile is never named again')
  assert.equal(Profiles.startupActiveName(LIST, '', '', ''), '')
})

test('a default profile is remembered only while it still exists', () => {
  assert.equal(Profiles.startupDefaultName(LIST, 'Green'), 'Green')
  assert.equal(Profiles.startupDefaultName(LIST, 'Mine'), 'Mine',
    'custom profiles may be defaults too')
  assert.equal(Profiles.startupDefaultName(LIST, 'Ghost'), '',
    'a deleted default is forgotten, not restored')
  assert.equal(Profiles.startupDefaultName(LIST, ''), '')
  assert.equal(Profiles.startupDefaultName(LIST, undefined), '')
})

test('built-in overrides survive restarts; Reset means no override', () => {
  const factory = Profiles.factoryMap(LIST)
  assert.deepEqual(Object.keys(factory), ['Amber', 'Green', 'Mine'])
  assert.equal(factory.Amber, '{"a":1}')

  const changes = Profiles.overridesToApply(
    Profiles.parseOverrides(JSON.stringify({ Amber: '{"a":9}' })), LIST)
  assert.equal(changes.length, 1, 'only the built-in that was saved')
  assert.equal(changes[0].name, 'Amber')
  assert.equal(changes[0].index, 0)
  assert.equal(changes[0].obj_string, '{"a":9}')

  // Custom profiles and unknown names are never written back...
  assert.equal(Profiles.overridesToApply(
    { Mine: '{"a":8}', Ghost: '{}' }, LIST).length, 0)
  // ...and Reset is exactly "no override": nothing is applied, so the
  // factory copy in the list stays what it shipped as.
  assert.equal(Profiles.overridesToApply(Profiles.parseOverrides('{}'), LIST).length, 0)
  assert.equal(factory.Amber, '{"a":1}')
})

test('garbage in storage means no overrides at all', () => {
  assert.deepEqual(Profiles.parseOverrides(undefined), {})
  assert.deepEqual(Profiles.parseOverrides(null), {})
  assert.deepEqual(Profiles.parseOverrides(''), {})
  assert.deepEqual(Profiles.parseOverrides('not json'), {})
  assert.deepEqual(Profiles.parseOverrides('[1,2]'), {}, 'not a name map')
  assert.deepEqual(Profiles.parseOverrides('"a string"'), {})
  assert.deepEqual(Profiles.parseOverrides('42'), {})
  assert.equal(Profiles.overridesToApply(null, LIST).length, 0)
  assert.equal(Profiles.overridesToApply('nope', LIST).length, 0)
})

test('profiles are found by name, and built-ins are recognisably built-in', () => {
  assert.equal(Profiles.indexOfName(LIST, 'Green'), 1)
  assert.equal(Profiles.indexOfName(LIST, 'Ghost'), -1)
  assert.equal(Profiles.indexOfName(LIST, ''), -1)
  assert.equal(Profiles.indexOfName(LIST, null), -1)
  assert.equal(Profiles.indexOfName(LIST, undefined), -1)
  assert.equal(Profiles.indexOfName(null, 'Amber'), -1)

  assert.equal(Profiles.isBuiltin(LIST, 'Amber'), true)
  assert.equal(Profiles.isBuiltin(LIST, 'Mine'), false)
  assert.equal(Profiles.isBuiltin(LIST, 'Ghost'), false)
})
