# asteroid_chunks.py

import pickle

from importlib.resources import files

from draftsman import data


try:
    source = files(data) / "asteroid_chunks.pkl"
    with source.open("rb") as inp:
        raw: dict[str, dict] = pickle.load(inp)
        """
        A dictionary where each key is the name of an asteroid chunk (Space
        Age) and its value is its ``data.raw["asteroid-chunk"]`` prototype
        entry.

        An asteroid collector gathers chunks in space, and a chunk's
        ``minable`` names the item gathering it yields. That makes this, like
        :py:mod:`draftsman.data.resources`, the game's own statement that an
        item is gathered rather than crafted: the chunk items also appear as
        results of reprocessing recipes, which turn chunks into chunks and so
        are not where they come from.

        Asteroid chunks are not blueprintable, so they never appear in
        :py:mod:`draftsman.data.entities`. Empty for a mod set without Space
        Age.

        :example:

        .. code-block:: python

            from draftsman.data import asteroid_chunks
            print(asteroid_chunks.raw["metallic-asteroid-chunk"]["minable"])

        .. code-block:: python

            {
                "result": "metallic-asteroid-chunk",
                "mining_time": 0.2,
                "mining_particle": "metallic-asteroid-chunk-particle-medium",
            }

        Space Age also defines ``parameter-0`` .. ``parameter-9`` and a hidden
        ``asteroid-chunk-unknown`` of this type, with no ``minable`` at all.

        :meta hide-value:
        """

except FileNotFoundError:  # pragma: no coverage
    raw: dict[str, dict] = {}
