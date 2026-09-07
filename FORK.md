# About this fork

This is a fork of [redruin1/factorio-draftsman](https://github.com/redruin1/factorio-draftsman)
carrying two fixes that have been reported upstream but not yet released. It exists so that
[factorio-forge](https://github.com/Fatoom333/factorio-forge) can depend on a working version
in the meantime, and it is intended to be temporary: once the fixes land upstream, the
dependency goes back to the released package and this branch is abandoned.

Nothing else is changed. The branch is cut from the `3.3.1` tag, not from `main`, because 4.0.0
cannot run `draftsman update` at all — see the third issue below.

## Branch

`3.3.1-forge` — upstream `3.3.1` plus the two patches. Version reports as `3.3.1+forge.1`.

## What is patched

### `require` does not return the cached module

`draftsman/compatibility/interface.lua` cleared `package.loaded` after every `require`, so
requiring the same file twice returned two different values. Mods routinely have one file
`require` a shared table and add to it, and another file `require` the same table and use what
was added; under the original code the second file received a freshly executed copy and the
additions were lost. `deadlock-beltboxes-loaders` fails this way, and so would any mod using
the same ordinary layout.

The cache is now keyed by the resolved file path, which `require` already computes, instead of
by the name as written. That keeps the cross-mod protection the original code was after — two
mods each having a `utils.lua` still get their own — while restoring caching within a mod.

Reported upstream, with the patch and a five-file reproduction.

### `space-platform-starter-pack` read without checking it exists

`draftsman/environment/update.py` extracted that prototype whenever the game version was 2.0 or
newer. It is a Space Age prototype, so it is absent whenever that expansion is not loaded, and
extraction crashed with `TypeError: 'NoneType' object is not iterable` for every mod set
without the expansion.

The condition now tests whether the prototype is present, which is what `get_signals` in the
same file already does for exactly this reason.

Reported upstream with the patch.

## Related upstream issue

[#227](https://github.com/redruin1/factorio-draftsman/issues/227) reports that 4.0.0 omits
`draftsman/compatibility/defines/*.lua` from the published wheel, which is why this fork is
based on 3.3.1. That one needs no patch here: the affected code does not exist in 3.3.1.

## Verified

- The `require` reproduction fails on upstream 3.3.1 and passes here.
- A 28-mod Krastorio 2 set that could not be extracted at all now extracts, giving 266
  entities and 1833 recipes, 92 of them Krastorio prototypes.
- A vanilla plus Space Age set that already worked produces the same output as before, so the
  cross-mod behaviour the original cache-clearing protected is intact.

All against Factorio 2.0.77 on Windows, Python 3.12.
