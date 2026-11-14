"""Verify the exported regression contract and benchmark JSON inference."""
import json
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class WeightExport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = json.loads((ROOT / "artifacts/weight-v1/weight.json").read_text())

    def test_contract(self):
        m = self.model
        self.assertEqual(m["input"], "reference_length_cm")
        self.assertEqual(m["output"], "estimated_weight_g")
        self.assertGreater(m["a"], 0)
        self.assertGreater(m["b"], 0)
        self.assertGreater(m["max_cm"], m["min_cm"])

    def test_reproducible_export(self):
        from models.weight.train import fit, predict, samples

        self.assertEqual({k: self.model[k] for k in fit(samples())}, fit(samples()))
        self.assertIsNone(predict(self.model, self.model["max_cm"] + 1))
        self.assertIsNone(predict(self.model, self.model["min_cm"] - 1))
        cm = (self.model["min_cm"] + self.model["max_cm"]) / 2
        start = time.perf_counter_ns()
        for _ in range(10000):
            predict(self.model, cm)
        print(f"JSON inference: {(time.perf_counter_ns() - start) / 10000 / 1000:.3f} µs/call (host)")


if __name__ == "__main__":
    unittest.main()
