"""Check center decoding and group separation independently of training."""
import unittest

import numpy as np

from models.count.train import peaks, split_groups


class CountContract(unittest.TestCase):
    def test_local_maxima(self):
        logits = np.full((1, 1, 5, 5), -10, dtype=np.float32)
        logits[0, 0, 1, 1] = 4
        logits[0, 0, 1, 2] = 3
        logits[0, 0, 4, 4] = 5
        self.assertEqual(peaks(logits, .25), [[0, 0, 1, 1], [0, 0, 4, 4]])

    def test_group_split_is_order_independent(self):
        days = list(range(30))
        splits = split_groups(days)
        self.assertEqual(splits, split_groups(list(reversed(days)) + days))
        self.assertEqual(set(splits.values()), {"train", "val", "test"})
