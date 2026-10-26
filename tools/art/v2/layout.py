"""Map layout shared with v1: the loop generator and island mask live in ../board.py."""

import importlib.util
import os

_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "board.py")
_spec = importlib.util.spec_from_file_location("board_v1", _path)
board = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(board)

W, H = board.W, board.H
SEED = 13


def island(seed=SEED):
    loop = board.generate(seed, pushes=6)
    land = board.land_mask(loop, 3, seed=seed)
    return loop, land
