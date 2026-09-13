# surfaces.py

import pickle

from importlib.resources import files

from draftsman import data


try:
    source = files(data) / "surfaces.pkl"
    with source.open("rb") as inp:
        _data = pickle.load(inp)
        raw: dict[str, dict] = _data[0]
        """
        A dictionary where each key is the name of a surface that is not a
        planet -- ``space-platform`` in Space Age -- and its value is its
        ``data.raw["surface"]`` prototype entry. Planets are in
        :py:mod:`draftsman.data.planets`.

        :example:

        .. code-block:: python

            from draftsman.data import surfaces
            print(surfaces.raw["space-platform"]["surface_properties"])

        :meta hide-value:
        """
        properties: dict[str, dict] = _data[1]
        """
        A dictionary where each key is the name of a surface property
        (``pressure``, ``gravity``, ``magnetic-field``, ...) and its value is its
        ``data.raw["surface-property"]`` prototype entry, including
        ``default_value``: what a surface that does not state the property has.

        :meta hide-value:
        """

except FileNotFoundError:  # pragma: no coverage
    raw: dict[str, dict] = {}
    properties: dict[str, dict] = {}
