'use strict'
/**
 * Tests for the managed CMS alias block (app/qml/logic/aliases.js).
 *
 * Run with:  node --test tests/logic
 */
const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const Aliases = require(path.join(__dirname, '..', '..', 'app', 'qml', 'logic', 'aliases.js'))

test('the block carries every CMS command from the list', () => {
  const b = Aliases.block()
  const expected = {
    FILEL: 'ls', FILELIST: 'ls', LISTFILE: 'ls -l', COPYFILE: 'cp',
    ERASE: 'rm -i', RENAME: 'mv', TYPE: 'cat', ACCESS: 'mount',
    RELEASE: 'umount', FORMAT: 'mkfs'
  }
  for (const [name, cmd] of Object.entries(expected))
    assert.ok(b.includes(`alias ${name}='${cmd}'`), `${name} alias missing`)

  // SAVE / FILE / FFILE are XEDIT side commands: documented, not aliased.
  assert.ok(b.includes('XEDIT'), 'XEDIT note missing')
  assert.equal(b.split('\n')[0], Aliases.START_MARKER, 'block starts with the marker')
  assert.ok(b.includes(Aliases.END_MARKER), 'closing marker missing')
})

test('upsert installs into an empty profile and is idempotent', () => {
  const once = Aliases.upsert('', Aliases.block())
  assert.equal(once.indexOf(Aliases.START_MARKER), 0, 'fresh file gets the block')
  const twice = Aliases.upsert(once, Aliases.block())
  assert.equal(twice, once, 'a second run must rewrite the same bytes')
  // Non-string content (a failed read) behaves like an empty file.
  assert.equal(Aliases.upsert(undefined, Aliases.block()), once)
})

test('upsert preserves the user content around the block', () => {
  const user = 'export EDITOR=vim\nalias ll="ls -la"\n'
  const withBlock = Aliases.upsert(user, Aliases.block())
  assert.ok(withBlock.startsWith(user), 'user content stays at the top')
  assert.equal(Aliases.upsert(withBlock, Aliases.block()), withBlock)
})

test('a moved or duplicated block collapses back to exactly one', () => {
  const block = Aliases.block()
  const messy = 'keep me\n' + block + '\nmiddle\n' + block + '\n'
  const fixed = Aliases.upsert(messy, block)
  assert.equal(fixed.split(Aliases.START_MARKER).length - 1, 1,
    'exactly one managed block survives')
  assert.ok(fixed.includes('keep me'), 'content before the block survives')
  assert.ok(fixed.includes('middle'), 'content between blocks survives')
  assert.equal(Aliases.upsert(fixed, block), fixed, 'and it is stable')
})

test('strip removes every trace and is idempotent', () => {
  const user = 'export EDITOR=vim\n'
  const withBlock = Aliases.upsert(user, Aliases.block())
  const stripped = Aliases.strip(withBlock)
  assert.equal(stripped.includes(Aliases.START_MARKER), false)
  assert.equal(stripped.includes(Aliases.END_MARKER), false)
  assert.ok(stripped.includes('export EDITOR=vim'), 'user content survives')
  assert.equal(Aliases.strip(stripped), stripped)
  assert.equal(Aliases.strip(''), '')
  // A file that only holds the block ends up empty, so bash starts clean.
  assert.equal(Aliases.strip(Aliases.upsert('', Aliases.block())), '')
})

test('targets: bashrc everywhere, zshrc on macOS, profiles only when present', () => {
  const none = () => false
  assert.deepEqual(Aliases.targets('linux', none), ['.bashrc'])
  assert.deepEqual(Aliases.targets('x11', none), ['.bashrc'])
  assert.deepEqual(Aliases.targets('windows', none), ['.bashrc'],
    'Git Bash reads ~/.bashrc -- the top-up story')

  // macOS: zsh is the default shell, so ~/.zshrc is ensured too.
  assert.deepEqual(Aliases.targets('osx', none), ['.bashrc', '.zshrc'])
  assert.deepEqual(Aliases.targets('macos', none), ['.bashrc', '.zshrc'])

  const has = (name) => name === '.zshrc' || name === '.profile'
  assert.deepEqual(Aliases.targets('linux', has),
    ['.bashrc', '.zshrc', '.profile'])

  const bashProfile = (name) => name === '.bash_profile'
  assert.deepEqual(Aliases.targets('linux', bashProfile),
    ['.bashrc', '.bash_profile'])

  // Never listed twice, even when several rules qualify.
  const all = () => true
  assert.deepEqual(Aliases.targets('osx', all),
    ['.bashrc', '.zshrc', '.bash_profile', '.profile'])

  // A missing probe degrades to "bashrc only".
  assert.deepEqual(Aliases.targets('linux'), ['.bashrc'])
})

test('HELP is a prompting function on Linux and macOS, absent on Windows', () => {
  for (const os of ['linux', 'x11', 'osx', 'macos', undefined]) {
    const b = Aliases.block(os)
    assert.ok(b.includes("alias HELP='help'"), `${os}: HELP alias missing`)
    assert.ok(b.includes('help() {'), `${os}: help function missing`)
    assert.ok(b.includes('man -k .'), `${os}: blank-topic listing missing`)
    assert.ok(b.includes('man -- "$topic"'), `${os}: topic man page missing`)
    assert.ok(b.includes('Topic'), `${os}: prompt missing`)
  }

  const win = Aliases.block('windows')
  assert.equal(win.includes('alias HELP='), false, 'Windows gets no HELP')
  assert.equal(win.includes('man -k .'), false, 'Windows gets no prompt')
  // ... but the ten CMS aliases are all still there.
  assert.ok(win.includes("alias FILEL='ls'"))
})
