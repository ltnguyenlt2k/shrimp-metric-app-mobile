import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "pipeline"))
sys.path.insert(0, str(ROOT / "models/detect"))
import gut  # noqa: E402
import run  # noqa: E402
import size  # noqa: E402
from data import paste  # noqa: E402


class PipelineTest(unittest.TestCase):
    def test_body_length_follows_principal_axis(self):
        mask = np.zeros((100, 100), bool)
        for i in range(60):  # diagonal bar, length 60 * sqrt(2)
            mask[20 + i, 20 + i:23 + i] = True
        length, width = size.measure(mask)
        self.assertAlmostEqual(length, 60 * 2 ** .5, delta=4)
        self.assertAlmostEqual(width, 3 / 2 ** .5 + 1, delta=1.5)

    def test_centre_line_follows_a_bent_body(self):
        mask = np.zeros((200, 200), bool)
        mask[20:120, 20:26] = True   # vertical arm, 100 px
        mask[114:120, 20:120] = True  # horizontal arm, 100 px
        length, _ = size.measure(mask)
        self.assertGreater(length, 150)  # the chord is only about 141 px

    def test_ruler_table_round_trip(self):
        grams, outside = size.weight_from_length(11.0, "tongwei")
        self.assertAlmostEqual(grams, 10.0, places=3)
        self.assertFalse(outside)
        summary = size.summarise([11.0, 11.0], "tongwei")
        self.assertEqual(summary["count_per_kg"], 100)
        self.assertTrue(size.weight_from_length(2.0, "tongwei")[1])

    def test_default_table_averages_both_rulers(self):
        low, high = (size.weight_from_length(8.0, name)[0] for name in ("tongwei", "growmax"))
        grams, outside = size.weight_from_length(8.0)
        self.assertAlmostEqual(grams, (low * high) ** .5, places=6)
        self.assertFalse(outside)
        # Above Growmax's last mark only Tongwei covers the length, so its value is used alone.
        self.assertAlmostEqual(size.weight_from_length(20.0)[0], size.weight_from_length(20.0, "tongwei")[0])

    def test_gut_index_reads_a_dark_midline(self):
        mask = np.zeros((40, 200), bool)
        mask[10:30, 10:190] = True
        mask[4:36, 10:60] = True  # wider head end on the left
        body = np.full((40, 200, 3), 170, np.uint8)
        self.assertEqual(gut.gut_fullness(body, mask)["level"], "empty")
        filled = body.copy()
        filled[18:22, 70:180] = 60  # dark line along the abdomen
        self.assertEqual(gut.gut_fullness(filled, mask)["level"], "full")
        self.assertEqual(gut.gut_fullness(body // 4, mask)["reason"], "body_too_dark")

    def test_quality_flags_flat_dark_frame(self):
        check = run.quality(Image.new("RGB", (640, 480), (5, 5, 5)), 480)
        self.assertFalse(check["valid"])
        self.assertIn("blurry", check["reasons"])
        self.assertIn("too_dark", check["reasons"])

    def test_paste_keeps_one_mask_per_animal_and_occludes(self):
        crop = Image.new("RGBA", (40, 12), (120, 90, 60, 255))
        image, masks = paste(np.full((200, 200, 3), 200, np.uint8), [], [crop], 5, (30, 40))
        self.assertEqual(len(masks), 5)
        self.assertLessEqual(int(np.sum(masks, axis=0).max()), 1)


if __name__ == "__main__":
    unittest.main()
