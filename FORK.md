# About this fork

This is a fork of [redruin1/factorio-draftsman](https://github.com/redruin1/factorio-draftsman)
carrying five fixes that have been reported upstream, or are about to be, but are not in a
release. It exists so that [factorio-forge](https://github.com/Fatoom333/factorio-forge) can
depend on a working version in the meantime, and it is meant to be temporary: once the fixes
land upstream, the dependency goes back to the released package and this branch is abandoned.

Nothing is changed beyond those five fixes, a version marker and this file.

The branch is cut from the `3.3.1` tag rather than from `main`, because 4.0.0 cannot run
`draftsman update` at all — see [Related upstream issue](#related-upstream-issue) at the end.

## Branch

`3.3.1-forge` — upstream `3.3.1` plus the patches below. Version reports as `3.3.1+forge.3`.

## What is patched

Four of the five share a shape, and it is worth naming because it predicts where the next one
will be: the code trusts prototype data to take one particular form when Factorio accepts
several, or to reference something that is not guaranteed to exist. Vanilla data always
satisfies those assumptions, so nothing surfaces until a mod does something equally legal and
different.

### `require` does not return the cached module

*Reported upstream, with the patch and a minimal reproduction.*

`draftsman/compatibility/interface.lua` cleared `package.loaded` after every `require`, so
requiring the same file twice returned two different values. Mods routinely have one file
`require` a shared table and add to it, and another file `require` the same table and use what
was added; under the original code the second file received a freshly executed copy and the
additions were lost. `deadlock-beltboxes-loaders` fails this way, and so would any mod using
the same ordinary layout.

The cache is now keyed by the resolved file path, which `require` already computes, instead of
by the name as written. That keeps the cross-mod protection the original code was after — two
mods each having a `utils.lua` still get their own — while restoring caching within a mod.

Caching also turns out to be cheaper than not caching. On a vanilla plus Space Age extraction,
1.91 s and a 189 MB peak with the cache against 6.08 s and 228 MB without: re-running a file on
every `require` both costs time and leaves duplicate tables alive.

### `space-platform-starter-pack` read without checking it exists

*Reported upstream with the patch.*

`draftsman/environment/update.py` extracted that prototype whenever the game version was 2.0 or
newer. It is a Space Age prototype, so it is absent whenever that expansion is not loaded, and
extraction crashed with `TypeError: 'NoneType' object is not iterable` for every mod set
without the expansion.

The condition now tests whether the prototype is present, which is what `get_signals` in the
same file already does for exactly this reason.

### `feature_flags` never reached mods

*Reported upstream with the patch and a probe mod.*

`run_data_lifecycle` built the `feature_flags` global by formatting a Python boolean into Lua
source:

```python
sa_enabled="space-age" in owned_dlc
```

`"{}".format(True)` produces `True`, but Lua's boolean literals are lowercase. `True` and
`False` are therefore read as undefined globals, so every flag came out `nil` — the same result
whether the expansion was owned or not.

The visible symptom is that `--no-dlc` changed nothing; it had in fact never worked, having
arrived in the same commit as the formatting mistake. The real cost is quieter: a mod that
gates content on `feature_flags.quality` or `feature_flags.freezing` silently contributed the
wrong variant, and the extracted data was wrong with no error anywhere. Mods comparing a flag
against `false` explicitly were affected too, since `nil == false` is false.

The flag is now emitted as `true` or `false`.

### A bounding box written both ways at once was unreadable

*Written up for upstream; not yet filed.*

Factorio accepts a bounding-box corner positionally, as `{-1, -1}`, or by name, as
`{x = -1, y = -1}`, and accepts the box itself either as a pair or as
`{left_top = ..., right_bottom = ...}`. A prototype may also supply a corner both ways at once.

`convert_table_to_dict` treats a Lua table as an array only when every key is an integer, so a
plain corner arrives as a list and a mixed one as a mapping. Two places then read the corner
positionally, which works for the first and raises `KeyError: 0` for the second. Vanilla
`spidertron` is written plainly and loads; `warptorio-warpspider` carries both forms and took
the whole extraction down with it.

Reading a corner now goes through one helper, `utils.bounding_box_corners`, which handles every
form the game accepts, and both call sites use it.

### An entity mined into an item that was not extracted took everything down

*Written up for upstream; not yet filed.*

`get_order` sorts an entity by the item it becomes when mined, and read that item straight out
of the item table:

```python
associated_item = object_to_sort["minable"]["result"]
...
sort_name = sort_objects[associated_item]["name"]   # KeyError
```

Nothing guarantees the mined result is an item we know about — a mod can name one that is
hidden, or that another mod removed. The fallback branch a few lines below already tested
membership before trusting a name; the first path now does the same and falls back rather than
raising.

Found through `warptorio-harvestpad-tag-5`, which is minable into an item that does not survive
extraction.

## Related upstream issue

[#227](https://github.com/redruin1/factorio-draftsman/issues/227) reports that 4.0.0 omits
`draftsman/compatibility/defines/*.lua` from the published wheel, so `draftsman update` fails
immediately on that release for every user, mod set and game version. That is why this fork is
based on 3.3.1, and it needs no patch here: the affected code does not exist in 3.3.1.

## Verified

Against Factorio 2.0.77 on Windows 10, Python 3.12.7, over a save folder of ninety-eight saves
containing eight distinct 2.0 mod sets.

- All eight mod sets extract. Before these patches, three could not: a 28-mod Krastorio 2 set,
  and two warptorio sets.
- The `require` reproduction fails on upstream 3.3.1 and passes here. The probe mod for
  `feature_flags` sees `nil` before and real booleans after.
- The bounding-box helper returns the same corners for all four spellings: a positional pair,
  named corners, a Lua 1-indexed table, and a corner carrying both key styles at once.
- Mod sets that already extracted still do, with unchanged entity counts.

One caveat on that last point: recipe *counts* are not a stable basis for comparison. Repeating
an identical extraction can yield slightly different recipe sets, because Factorio's own data
stage extends `data.raw.recipe` while iterating it — undefined in Lua — and the stock Lua here
seeds its string hashing per process. Entity counts were stable across every run and are what
the comparisons above use. This is a separate matter from the patches, and is discussed on
upstream issue #214.
