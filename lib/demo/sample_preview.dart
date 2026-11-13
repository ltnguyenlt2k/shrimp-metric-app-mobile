import 'package:material_ui/material_ui.dart';

const _regions = [
  Rect.fromLTWH(137, 141, 69, 36),
  Rect.fromLTWH(228, 135, 69, 31),
  Rect.fromLTWH(321, 111, 40, 65),
  Rect.fromLTWH(475, 94, 71, 48),
  Rect.fromLTWH(727, 88, 65, 58),
  Rect.fromLTWH(640, 146, 66, 27),
  Rect.fromLTWH(503, 165, 66, 38),
  Rect.fromLTWH(807, 172, 61, 48),
  Rect.fromLTWH(121, 205, 54, 49),
  Rect.fromLTWH(180, 234, 51, 60),
  Rect.fromLTWH(216, 268, 49, 63),
  Rect.fromLTWH(297, 231, 31, 75),
  Rect.fromLTWH(389, 187, 37, 63),
  Rect.fromLTWH(429, 268, 68, 24),
  Rect.fromLTWH(491, 200, 72, 44),
  Rect.fromLTWH(586, 249, 61, 54),
  Rect.fromLTWH(710, 201, 45, 75),
  Rect.fromLTWH(805, 250, 52, 80),
  Rect.fromLTWH(372, 297, 74, 42),
  Rect.fromLTWH(496, 344, 75, 26),
  Rect.fromLTWH(622, 305, 42, 59),
  Rect.fromLTWH(702, 315, 79, 48),
  Rect.fromLTWH(111, 395, 68, 49),
  Rect.fromLTWH(235, 369, 58, 57),
  Rect.fromLTWH(303, 389, 65, 64),
  Rect.fromLTWH(427, 380, 24, 82),
  Rect.fromLTWH(477, 411, 99, 33),
  Rect.fromLTWH(661, 373, 43, 78),
  Rect.fromLTWH(745, 447, 86, 24),
  Rect.fromLTWH(163, 467, 64, 41),
  Rect.fromLTWH(272, 503, 73, 35),
  Rect.fromLTWH(378, 484, 58, 54),
  Rect.fromLTWH(471, 495, 71, 43),
  Rect.fromLTWH(637, 491, 63, 49),
  Rect.fromLTWH(767, 510, 67, 39),
  Rect.fromLTWH(117, 554, 65, 48),
  Rect.fromLTWH(228, 563, 84, 28),
  Rect.fromLTWH(564, 535, 48, 68),
];

final demoDetectionCount = _regions.length;

class SamplePreview extends StatelessWidget {
  const SamplePreview({this.marked = false, super.key});

  final bool marked;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 1,
      child: AspectRatio(
        aspectRatio: 1000 / 667,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/demo/shrimp-tray.jpg',
              fit: BoxFit.fill,
              semanticLabel: 'Ảnh minh họa khay tôm',
            ),
            if (marked) const CustomPaint(painter: _DetectionPainter()),
          ],
        ),
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  const _DetectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFF005D50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()..color = const Color(0x3300A889);
    for (final region in _regions) {
      final box = Rect.fromLTRB(
        region.left * size.width / 1000,
        region.top * size.height / 667,
        region.right * size.width / 1000,
        region.bottom * size.height / 667,
      );
      canvas.drawRect(box, fill);
      canvas.drawRect(box, outline);
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter oldDelegate) => false;
}
