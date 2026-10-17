import importlib.util
import os
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location(
    "relative_resize", Path(os.environ["KITTY_SPLITS_DIR"]) / "relative_resize.py"
)
resize = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resize)


class ResizeTests(unittest.TestCase):
    def test_resize_moves_the_border_in_the_requested_direction(self):
        cases = [
            ("left", {"left": [2]}, "wider"),
            ("left", {"right": [2]}, "narrower"),
            ("left", {"left": [2], "right": [3]}, "narrower"),
            ("right", {"left": [2]}, "narrower"),
            ("right", {"right": [2]}, "wider"),
            ("right", {"left": [2], "right": [3]}, "wider"),
            ("up", {"top": [2]}, "taller"),
            ("up", {"bottom": [2]}, "shorter"),
            ("up", {"top": [2], "bottom": [3]}, "shorter"),
            ("down", {"top": [2]}, "shorter"),
            ("down", {"bottom": [2]}, "taller"),
            ("down", {"top": [2], "bottom": [3]}, "taller"),
        ]
        for direction, neighbors, expected in cases:
            with self.subTest(direction=direction, neighbors=neighbors):
                calls = []
                tab = SimpleNamespace(
                    windows=[],
                    current_layout=SimpleNamespace(neighbors_for_window=lambda *args: neighbors),
                    resize_window=lambda quality, amount: calls.append((quality, amount)),
                )
                boss = SimpleNamespace(window_id_map={1: object()}, active_tab=tab)
                resize.relative_resize_window(direction, 3, 1, boss)
                self.assertEqual(calls, [(expected, 3)])

    def test_single_window_and_closed_target_do_not_resize(self):
        tab = SimpleNamespace(
            windows=[], current_layout=SimpleNamespace(neighbors_for_window=lambda *args: {}),
            resize_window=lambda *args: self.fail("window without neighbors must not resize"),
        )
        boss = SimpleNamespace(window_id_map={1: object()}, active_tab=tab)
        resize.relative_resize_window("left", 3, 1, boss)
        resize.relative_resize_window("left", 3, 2, boss)


if __name__ == "__main__":
    unittest.main()
