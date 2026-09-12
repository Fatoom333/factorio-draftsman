# resources.py

import pickle

from importlib.resources import files

from draftsman import data


try:
    source = files(data) / "resources.pkl"
    with source.open("rb") as inp:
        raw: dict[str, dict] = pickle.load(inp)
        """
        A dictionary where each key is the name of a resource entity (an ore
        patch, a crude-oil well, and the like) and its value is its
        ``data.raw["resource"]`` prototype entry.

        This is the game's own way of distinguishing a mined raw material
        from a crafted one: any item or fluid named in ``minable`` here is
        raw, whatever recipe might otherwise appear to produce it (Krastorio
        2's coal filtration recipe makes coal look craftable by name alone,
        but coal is still a leaf: it is also a mining result). ``category``
        is the resource's ``resource_category`` -- what a mining drill's own
        ``resource_categories`` must intersect to be able to work it.

        Resource entities are not blueprintable, so they never appear in
        :py:mod:`draftsman.data.entities` -- that module only extracts
        prototype types the game allows placing in a blueprint.

        :example:

        .. code-block:: python

            from draftsman.data import resources
            print(resources.raw["iron-ore"])

        .. code-block:: python

            {
                "type": "resource",
                "name": "iron-ore",
                "category": "basic-solid",
                "minable": {
                    "mining_time": 1,
                    "result": "iron-ore",
                },
                ...
            }

        A resource that needs an input fluid to mine (uranium ore) carries
        ``required_fluid``/``fluid_amount`` alongside ``minable``; one that
        yields more than one item/fluid (Space Age asteroid chunks) carries
        ``minable["results"]`` -- a list of stacks -- instead of a single
        ``minable["result"]``.

        :meta hide-value:
        """

except FileNotFoundError:  # pragma: no coverage
    raw: dict[str, dict] = {}
