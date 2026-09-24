'use strict'
/**
 * Tests for the IBM PF/PA key model (app/qml/logic/pfkeys.js).
 *
 * Run with:  node --test tests/logic
 */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const PfKeys = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'pfkeys.js'))

test('keyboard shape matches an IBM 3270 family terminal', () => {
  assert.equal(PfKeys.PF_COUNT, 12, 'twelve PF keys')
  assert.equal(PfKeys.PA_COUNT, 3, 'three Program Attention keys')
  assert.equal(PfKeys.KEY_COUNT, 15)
})

test('default PF slots are F1..F12 in order', () => {
  for (let i = 0; i < 12; i++) {
    assert.equal(PfKeys.defaultKeyFor(i), `F${i + 1}`)
    assert.equal(PfKeys.defaultLabelFor(i), `PF${i + 1}`)
    assert.ok(PfKeys.isPf(i))
  }
  assert.equal(PfKeys.isPf(12), false)
})

test('PA slots use the IBM PC/3270 default bindings', () => {
  // IBM: PA1 = Ctrl+F1, PA2 = Ctrl+F2, PA3 = Ctrl+F3.
  assert.equal(PfKeys.defaultKeyFor(12), 'Ctrl+F1')
  assert.equal(PfKeys.defaultKeyFor(13), 'Ctrl+F2')
  assert.equal(PfKeys.defaultKeyFor(14), 'Ctrl+F3')
  assert.equal(PfKeys.defaultLabelFor(12), 'PA1')
  assert.equal(PfKeys.defaultLabelFor(14), 'PA3')
})

test('defaults are the factory PF panel: menu functions, no shell commands', () => {
  const defs = PfKeys.defaultAssignments()
  assert.equal(defs.length, PfKeys.KEY_COUNT)
  const expected = [
    'help', 'splitVertical', 'closeWindow', 'nextWindow', 'prevWindow',
    'splitHorizontal', 'toggleKeySound', 'settings', 'newTab', 'quit',
    'fullscreen', 'newWindow'
  ]
  assert.deepEqual(PfKeys.PF_DEFAULT_ACTIONS, expected)
  for (let i = 0; i < 12; i++) {
    assert.equal(defs[i].action, expected[i], `PF${i + 1}`)
    assert.equal(PfKeys.intercepts(defs[i]), true,
      `PF${i + 1} carries its function out of the box`)
    assert.notEqual(PfKeys.legend(defs[i]), '',
      `PF${i + 1} prints a legend`)
    assert.equal(PfKeys.actionById(defs[i].action).kind, 'app',
      `PF${i + 1} is an app function, not a command`)
  }

  // Shell commands (FILEL, XEDIT, macros) never ride a factory key: the
  // CMS set lives in the alias block, the panel stays functions-only --
  // though they remain in the catalogue for manual assignment.
  assert.ok(PfKeys.isKnownAction('fileList'))
  assert.ok(PfKeys.isKnownAction('xedit'))

  // PA1 still ships as the 3270 attention key; PA2/PA3 pass through.
  assert.equal(defs[12].action, 'interrupt')
  assert.equal(defs[13].action, 'pass')
  assert.equal(defs[14].action, 'pass')
  assert.equal(PfKeys.anyIntercepting(defs), true)
  const allPass = defs.map(a => ({ ...a, action: 'pass' }))
  assert.equal(PfKeys.anyIntercepting(allPass), false)
})

test('PA1 defaults to the 3270 attention/break key', () => {
  const defs = PfKeys.defaultAssignments()
  const pa1 = defs[12]
  assert.equal(pa1.action, 'interrupt')
  assert.equal(PfKeys.intercepts(pa1), true)
  const act = PfKeys.actionById('interrupt')
  assert.equal(act.kind, 'term')
  // SIGINT == Ctrl+C
  assert.equal(act.payload, '\u0003')
})

test('attention and erase-input payloads are the POSIX equivalents', () => {
  assert.equal(PfKeys.actionById('interrupt').payload, '\u0003')
  assert.equal(PfKeys.actionById('eraseInput').payload, '\u0015') // Ctrl+U
})

test('every action id referenced by a slot exists in the catalogue', () => {
  const ids = PfKeys.actionIds()
  assert.ok(ids.includes('newWindow'))
  assert.ok(ids.includes('nextWindow'))
  assert.ok(ids.includes('closeWindow'))
  assert.ok(ids.includes('interrupt'))
  assert.ok(ids.includes('sendText'))
  for (const id of ids) {
    assert.ok(PfKeys.isKnownAction(id), `catalogue contains ${id}`)
  }
  assert.equal(PfKeys.isKnownAction('definitelyNotAnAction'), false)
})

test('normalize repairs short, null and unknown input', () => {
  assert.equal(PfKeys.normalize(null).length, PfKeys.KEY_COUNT)
  assert.equal(PfKeys.normalize(undefined).length, PfKeys.KEY_COUNT)
  assert.equal(PfKeys.normalize([]).length, PfKeys.KEY_COUNT)
  assert.equal(PfKeys.normalize('garbage').length, PfKeys.KEY_COUNT)

  const half = [{ action: 'newWindow' }]
  const out = PfKeys.normalize(half)
  assert.equal(out.length, PfKeys.KEY_COUNT)
  assert.equal(out[0].action, 'newWindow')
  assert.equal(out[0].key, 'F1', 'missing key falls back to the slot default')
  assert.equal(out[1].action, 'splitVertical', 'missing slots fall back to defaults')
  assert.equal(out[0].label, 'PF1')
})

test('normalize replaces unknown action ids with the default', () => {
  const out = PfKeys.normalize([{ action: 'launchMissiles', key: 'F1' }])
  assert.equal(out[0].action, 'help')
})

test('serialize/parse round trips', () => {
  const list = PfKeys.defaultAssignments()
  list[0] = { key: 'F1', label: 'PF1', action: 'nextWindow', payload: '' }
  list[3] = { key: 'Ctrl+Alt+N', label: 'PF4', action: 'sendText', payload: 'ls -la\\n' }

  const restored = PfKeys.parse(PfKeys.serialize(list))
  assert.equal(restored.length, PfKeys.KEY_COUNT)
  assert.deepEqual(restored[0], list[0])
  assert.deepEqual(restored[3], list[3])
  assert.equal(PfKeys.intercepts(restored[0]), true)
  assert.equal(PfKeys.anyIntercepting(restored), true)
})

test('parse tolerates corrupt stored values', () => {
  assert.equal(PfKeys.parse(undefined).length, PfKeys.KEY_COUNT)
  assert.equal(PfKeys.parse('').length, PfKeys.KEY_COUNT)
  assert.equal(PfKeys.parse('{ not json').length, PfKeys.KEY_COUNT)
  assert.equal(PfKeys.parse('[1,2,3]').length, PfKeys.KEY_COUNT)
})

test('legend only shows an entry when a function is assigned', () => {
  const pass = { action: 'pass' }
  assert.equal(PfKeys.legend(pass), '')

  const win = { action: 'newWindow' }
  assert.equal(PfKeys.legend(win), 'New Window')

  const text = { action: 'sendText', payload: 'clear' }
  assert.equal(PfKeys.legend(text), 'clear', 'sendText shows what it sends')

  assert.equal(PfKeys.legend(null), '')
  assert.equal(PfKeys.legend(undefined), '')
})

test('only assigned functions register a shortcut', () => {
  const pass = { action: 'pass' }
  const app = { action: 'nextWindow' }
  assert.equal(PfKeys.intercepts(pass), false)
  assert.equal(PfKeys.intercepts(app), true)
  assert.equal(PfKeys.intercepts(null), false)
  assert.equal(PfKeys.intercepts(undefined), false)
  assert.equal(PfKeys.intercepts({ action: 'bogus' }), false)
})

test('assignableActions can hide actions the OS owns', () => {
  const all = PfKeys.assignableActions(0, {})
  const blocked = PfKeys.assignableActions(0, { nextWindow: true })

  assert.ok(all.length > blocked.length, 'blocking removes entries')
  assert.equal(blocked.some(a => a.id === 'nextWindow'), false)
  assert.equal(blocked.some(a => a.id === 'newWindow'), true)
  // "Off" must always be offered so a key can be released back to the shell.
  assert.equal(blocked.some(a => a.id === 'pass'), true)
})

test('collisions find duplicate key sequences', () => {
  const clean = PfKeys.defaultAssignments()
  assert.deepEqual(PfKeys.collisions(clean), [])

  const dirty = PfKeys.defaultAssignments()
  dirty[0].key = 'F2'
  const groups = PfKeys.collisions(dirty)
  assert.equal(groups.length, 1)
  assert.deepEqual(groups[0].sort(), [0, 1])
})

test('decodePayload understands macro escapes', () => {
  assert.equal(PfKeys.decodePayload('ls\\n'), 'ls\n')
  assert.equal(PfKeys.decodePayload('a\\tb'), 'a\tb')
  assert.equal(PfKeys.decodePayload('\\e[31m'), '\u001b[31m')
  assert.equal(PfKeys.decodePayload('C:\\\\tmp'), 'C:\\tmp')
  assert.equal(PfKeys.decodePayload('plain'), 'plain')
  assert.equal(PfKeys.decodePayload(null), '')
  assert.equal(PfKeys.decodePayload(undefined), '')
  // Trailing lone backslash is preserved rather than swallowed.
  assert.equal(PfKeys.decodePayload('ends\\'), 'ends\\')
})

test('macroText decodes and turns line feeds into carriage returns', () => {
  // A macro that says "ls -la\n" must behave exactly like typing the
  // command and pressing Enter, and Enter on a terminal sends CR.
  assert.equal(PfKeys.macroText('ls -la\\n'), 'ls -la\r')
  assert.equal(PfKeys.macroText('pwd\\nwhoami\\n'), 'pwd\rwhoami\r')
  assert.equal(PfKeys.macroText('no newline'), 'no newline')
  assert.equal(PfKeys.macroText(null), '')
  // Escapes are decoded before the CR mapping, so \e[31m survives intact.
  assert.equal(PfKeys.macroText('\\e[31mred\\e[0m\\n'),
               '\u001b[31mred\u001b[0m\r')
})

test('FILEL and XEDIT are catalogue functions with fixed legends', () => {
  const fileList = PfKeys.actionById('fileList')
  const xedit = PfKeys.actionById('xedit')
  assert.ok(fileList, 'FILEL exists')
  assert.ok(xedit, 'XEDIT exists')
  assert.equal(fileList.kind, 'term')
  assert.equal(xedit.kind, 'term')
  // The legend reads exactly what the operator calls the key.
  assert.equal(PfKeys.legend({ action: 'fileList' }), 'FILEL')
  assert.equal(PfKeys.legend({ action: 'xedit' }), 'XEDIT')
  // Both claim their F-key rather than passing it to the shell.
  assert.equal(PfKeys.intercepts({ action: 'fileList' }), true)
  assert.equal(PfKeys.intercepts({ action: 'xedit' }), true)
  // And both are offered in the editor.
  const offered = PfKeys.assignableActions(0, {})
  assert.ok(offered.some(a => a.id === 'fileList'))
  assert.ok(offered.some(a => a.id === 'xedit'))
})

test('commandFor resolves FILEL and XEDIT per platform', () => {
  // FILEL: ls on unix, dir on Windows -- dir works in cmd.exe and in
  // PowerShell alike (it is an alias there), covering "either dir or ls".
  assert.equal(PfKeys.commandFor('fileList', 'x11'), 'ls\r')
  assert.equal(PfKeys.commandFor('fileList', 'wayland'), 'ls\r')
  assert.equal(PfKeys.commandFor('fileList', 'mac'), 'ls\r')
  assert.equal(PfKeys.commandFor('fileList', 'osx'), 'ls\r')
  assert.equal(PfKeys.commandFor('fileList', 'win32'), 'dir\r')

  // XEDIT: vi on unix (POSIX guarantees it), notepad on Windows.
  assert.equal(PfKeys.commandFor('xedit', 'x11'), 'vi\r')
  assert.equal(PfKeys.commandFor('xedit', 'mac'), 'vi\r')
  assert.equal(PfKeys.commandFor('xedit', 'win32'), 'notepad\r')

  // Fixed-payload actions are not handled here; caller falls back.
  assert.equal(PfKeys.commandFor('interrupt', 'x11'), '')
  assert.equal(PfKeys.commandFor('eraseInput', 'win32'), '')
  assert.equal(PfKeys.commandFor('sendText', 'x11'), '')
  assert.equal(PfKeys.commandFor('notAnAction', 'x11'), '')
})

test('commandFor accepts every spelling of the Windows platform name', () => {
  // Qt has shipped both "win32" and "windows"; the terminal passes
  // Qt.platform.os straight through, so neither spelling may be missed.
  for (const os of ['win32', 'windows', 'win', 'WIN64']) {
    assert.equal(PfKeys.commandFor('fileList', os), 'dir\r', os)
    assert.equal(PfKeys.commandFor('xedit', os), 'notepad\r', os)
  }
  assert.equal(PfKeys.commandFor('fileList', 'osx'), 'ls\r')
  assert.equal(PfKeys.commandFor('fileList', undefined), 'ls\r')
  assert.equal(PfKeys.commandFor('fileList', null), 'ls\r')
})

test('the panel catalog gained the window functions the defaults need', () => {
  const ids = PfKeys.actionIds()
  for (const id of ['help', 'splitVertical', 'splitHorizontal',
                    'toggleKeySound', 'quit']) {
    assert.ok(ids.includes(id), `${id} missing from the catalogue`)
    assert.equal(PfKeys.actionById(id).kind, 'app')
  }
  // Labels the panel prints verbatim (uppercased by the bar).
  assert.equal(PfKeys.actionById('help').label, 'Help')
  assert.equal(PfKeys.actionById('prevWindow').label, 'Previous Window')
  assert.equal(PfKeys.actionById('fullscreen').label, 'Exit Full Screen')
  assert.equal(PfKeys.actionById('quit').label, 'Exit')
})

test('helpCommand maps the input box to man exactly as specified', () => {
  // Blank topic -> list the whole manual (CMS HELP with no operand).
  assert.equal(PfKeys.helpCommand(''), 'man -k .\r')
  assert.equal(PfKeys.helpCommand('   '), 'man -k .\r')
  assert.equal(PfKeys.helpCommand(undefined), 'man -k .\r')
  assert.equal(PfKeys.helpCommand(null), 'man -k .\r')
  // A topic -> that man page, quoted so spaces and quotes survive the shell.
  assert.equal(PfKeys.helpCommand('printf'), "man -- 'printf'\r")
  assert.equal(PfKeys.helpCommand('  pwd  '), "man -- 'pwd'\r")
  assert.equal(PfKeys.helpCommand('echo hi'), "man -- 'echo hi'\r")
  assert.equal(PfKeys.helpCommand("a'b"), "man -- 'a'\\''b'\r")
})

test('Bigger/Smaller are catalogue functions, offered but never factory keys', () => {
  // Screen size as a PF function: the same rungs Zoom In / Zoom Out
  // climb, so the key still works where a chord might be swallowed
  // (full screen).  Bindable by hand; the factory panel is unchanged.
  const bigger = PfKeys.actionById('bigger')
  const smaller = PfKeys.actionById('smaller')
  assert.ok(bigger, 'bigger missing from the catalogue')
  assert.ok(smaller, 'smaller missing from the catalogue')
  assert.equal(bigger.kind, 'app')
  assert.equal(smaller.kind, 'app')
  assert.equal(PfKeys.legend({ action: 'bigger' }), 'Bigger')
  assert.equal(PfKeys.legend({ action: 'smaller' }), 'Smaller')
  assert.equal(PfKeys.intercepts({ action: 'bigger' }), true,
    'the PF key claims its chord rather than passing it to the shell')

  const offered = PfKeys.assignableActions(0, {})
  assert.ok(offered.some(a => a.id === 'bigger'), 'the editor must offer it')
  assert.ok(offered.some(a => a.id === 'smaller'), 'the editor must offer it')
  for (const id of PfKeys.PF_DEFAULT_ACTIONS) {
    assert.notEqual(id, 'bigger', 'it must not claim a factory PF key')
    assert.notEqual(id, 'smaller', 'it must not claim a factory PF key')
  }
})

test('Save Profile sits in the catalogue but never on a factory key', () => {
  // The settings dialog's Save is bindable by hand, the way FILEL and
  // XEDIT are -- but the factory panel is functions the menus already
  // cover, so it ships unassigned.
  const save = PfKeys.actionById('saveProfile')
  assert.ok(save, 'saveProfile missing from the catalogue')
  assert.equal(save.kind, 'app')
  assert.equal(save.label, 'Save Profile')
  assert.ok(PfKeys.assignableActions(0, {}).some(a => a.id === 'saveProfile'),
    'the editor must offer it')
  for (const id of PfKeys.PF_DEFAULT_ACTIONS) {
    assert.notEqual(id, 'saveProfile', 'it must not claim a factory PF key')
  }
  // The panel would print it honestly if a user did bind it.
  assert.equal(PfKeys.legend({ action: 'saveProfile' }), 'Save Profile')
  assert.equal(PfKeys.intercepts({ action: 'saveProfile' }), true)
})
