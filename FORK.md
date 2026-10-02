# About this fork

This is a fork of [redruin1/factorio-draftsman](https://github.com/redruin1/factorio-draftsman)
for [factorio-forge](https://github.com/Fatoom333/factorio-forge). It carries three fixes that
are reported upstream but not merged, and three additions that are not going upstream (see
[What is added](#what-is-added)). The fixes are temporary: each is dropped once it is in
upstream `main`. The additions stay.

Nothing is changed beyond those, a version marker, this file and the note at the top of the
README.

## Branch

`main-forge` — upstream `main` at `8d7a0f6` (unreleased 4.0.1) plus the commits below. It is
cut from `main` rather than from the 4.0.0 tag because 4.0.0 cannot run `draftsman update` at
all ([#227](https://github.com/redruin1/factorio-draftsman/issues/227), fixed in `main`).
Version reports as `4.0.0+forge.1`.

The previous branch, `3.3.1-forge`, was cut from the 3.3.1 tag and carried eight fixes. Seven
of them are now in upstream `main` in upstream's own form (#227–#233, below), so they are not
repeated here. That branch is kept unchanged as a fallback.

To bring the branch up to date: rebase it onto the new upstream `main`, drop any commit whose
fix upstream now has, and re-extract the three added pickles if upstream's default data moved
to another game version.

## What is patched

### `encode_mod_settings` could not write a readable `mod-settings.dat`

*[#235](https://github.com/redruin1/factorio-draftsman/issues/235), fixed in
[PR #236](https://github.com/redruin1/factorio-draftsman/pull/236), not merged yet.* The commit
here is the PR's commit.

The encoder could not run at all (`struct.pack` without its value), wrote strings without the
presence byte the reader expects, wrote dictionary keys with a type header, never encoded a
dictionary (`type(dict) is dict`), and wrote the header version in the reverse order of the
game's own files. The reader could not read a list or an unsigned integer. With the fix, a
`mod-settings.dat` written by Factorio 2.0.60 decodes and re-encodes byte for byte.
`write_mod_settings` also takes an optional `factorio_version`, which forge passes.

### The global `unpack` was missing in the data stage

*[#237](https://github.com/redruin1/factorio-draftsman/issues/237), open.*

Factorio's Lua keeps the Lua 5.1 global `unpack`; Lupa's 5.2 has only `table.unpack`.
Factorissimo 3 calls bare `unpack` in `data-updates` and failed to extract. One line in
`compatibility/interface.lua`, next to the existing `math.pow` shim.

### `parse_energy` raised on fractional amounts

*[#238](https://github.com/redruin1/factorio-draftsman/issues/238), open.*

`"0.4kW"` and `"1.8MW"` appear in vanilla data, and Factorio's own `util.parse_energy` reads them
with `tonumber`; draftsman used `int()` and raised. Now `float()`, with the return type and
rounding unchanged.

## Fixed upstream, no longer patched here

The other seven fixes from `3.3.1-forge`, now in upstream `main` and taken from there:

- `require` returning the cached module ([#228](https://github.com/redruin1/factorio-draftsman/issues/228)) —
  patch in `main`, issue still open while the maintainer checks Factorio 2.1.17;
- `space-platform-starter-pack` read without checking it exists (#229);
- `feature_flags` always `nil` (#230);
- a bounding box written both positionally and by name (#231) — `utils.read_bounding_box`;
- an entity minable into an item that was not extracted (#232) — upstream extracts
  `item-with-tags`/`-label`/`-inventory` and, deliberately, adds no fallback in `get_order`:
  `draftsman update` should fail on invalid data as the game does;
- an inserter's stated pickup and drop positions (#233) — upstream returns `None` when a
  position is unknown, rather than `(0, 0)`;
- a debug print in the constant combinator (#223, fixed in 4.0.0).

## What is added

These are not bugs and are not going upstream: they are parts of the game's data draftsman
leaves out on purpose, because they are not blueprintable, and forge needs them anyway.

### Resource entities (`data.raw["resource"]`)

Ore patches, crude oil and the like. Their `category` and `minable` are the only place the game
says an item is mined rather than crafted, which `resource_category` a drill needs, and what
input fluid a patch requires. `extract_resources` writes `resources.pkl`, loaded by
`draftsman.data.resources`.

### Asteroid chunks (`data.raw["asteroid-chunk"]`)

What a Space Age asteroid collector gathers; a chunk's `minable` names the item it yields.
Without it the chunk items appear only as results of reprocessing recipes, which turn chunks into
chunks. `extract_asteroid_chunks` writes `asteroid_chunks.pkl`, loaded by
`draftsman.data.asteroid_chunks`; empty without Space Age.

### Surfaces and surface properties (`data.raw["surface"]`, `data.raw["surface-property"]`)

A planet is one kind of surface; the space platform is a `surface` with its own
`surface_properties`. The `surface-property` prototypes carry each property's `default_value`.
Both are needed to check `surface_conditions`. `extract_surfaces` writes
`[surfaces, properties]` to `surfaces.pkl`, loaded by `draftsman.data.surfaces` as `raw` and
`properties`.

### The committed default data carries the additions

`resources.pkl`, `asteroid_chunks.pkl` and `surfaces.pkl` are extracted from vanilla Factorio
2.1.17 (the `factorio-data` submodule, `draftsman update --no-mods`), the same data upstream's
own pickles come from. Upstream's pickles are left exactly as upstream generated them:
re-extracting reproduces them apart from recipe-order noise (see #214), so regenerating them
would only add a noisy diff.

## Verified

On Windows 11, Python 3.14, against upstream `main` `8d7a0f6`:

- `test/test_mod_settings.py` (from PR #236): 5 failed before, 5 passed after;
- `parse_energy` fractional cases added to `test/test_utils.py`;
- Factorissimo 3.11.19 alone on vanilla 2.0.77 fails to extract on `main` with
  `attempt to call global 'unpack'` and extracts with the shim;
- the three added pickles: 12 resources (the same names as from 2.0.77), 15 asteroid chunks,
  the space platform surface and 6 surface properties.
