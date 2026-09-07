# About this fork

This is a fork of [redruin1/factorio-draftsman](https://github.com/redruin1/factorio-draftsman)
carrying two fixes that have been reported upstream but not yet released. It exists so that
[factorio-forge](https://github.com/Fatoom333/factorio-forge) can depend on a working version
in the meantime, and it is intended to be temporary: once the fixes land upstream, the
dependency goes back to the released package and this branch is abandoned.

Nothing else is changed. The branch is cut from the `3.3.1` tag, not from `main`, because 4.0.0
cannot run `draftsman update` at all — see the third issue below.

## Branch

`3.3.1-forge` — upstream `3.3.1` plus the patches below. Version reports as
`3.3.1+forge.3`.

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

### `feature_flags` never reached mods

`run_data_lifecycle` built the `feature_flags` global by formatting a Python
boolean into Lua source:

```python
sa_enabled="space-age" in owned_dlc
```

`"{}".format(True)` produces `True`, but Lua's boolean literals are lowercase.
`True` and `False` are therefore read as undefined globals, so every flag came
out `nil` — the same result whether the expansion was owned or not.

The visible symptom is that `--no-dlc` changed nothing. The real cost is
quieter: a mod that gates content on `feature_flags.quality` or
`feature_flags.freezing` silently contributed the wrong variant, and the
extracted data was wrong with no error anywhere. It also affects mods that
compare a flag against `false` explicitly, since `nil == false` is false.

The flag is now emitted as `true` or `false`.

### A bounding box written both ways at once was unreadable

Factorio accepts a bounding-box corner positionally, as `{-1, -1}`, or by name,
as `{x = -1, y = -1}`, and accepts the box itself either as a pair or as
`{left_top = ..., right_bottom = ...}`. A prototype may also supply a corner
both ways at once.

`convert_table_to_dict` treats a Lua table as an array only when every key is an
integer, so a plain corner arrives as a list and a mixed one as a mapping. Two
places then read the corner positionally, which works for the first and raises
`KeyError: 0` for the second. Vanilla `spidertron` is written plainly and loads;
`warptorio-warpspider` carries both forms and takes the whole extraction down
with it.

Reading a corner is now done by one helper, `utils.bounding_box_corners`, which
accepts every accepted form, and both call sites use it.

### An entity mined into an item that was not extracted took everything down

`get_order` sorts an entity by the item it becomes when mined, and read that
item straight out of the item table:

```python
associated_item = object_to_sort["minable"]["result"]
...
sort_name = sort_objects[associated_item]["name"]   # KeyError
```

Nothing guarantees the mined result is an item we know about — a mod can name
one that is hidden, or that another mod removed. The fallback branch a few lines
below already tested membership before trusting a name; the first path now does
the same and falls back rather than raising.

Found through `warptorio-harvestpad-tag-5`, which is minable into an item that
does not survive extraction.

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
