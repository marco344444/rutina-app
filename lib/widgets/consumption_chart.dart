import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/inventory_statistics.dart';

class ConsumptionChart extends StatelessWidget {
  const ConsumptionChart({required this.buckets, super.key});

  final List<ConsumptionBucket> buckets;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ConsumptionPainter(
        buckets: buckets,
        color: Theme.of(context).colorScheme.primary,
        trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
        textDirection: Directionality.of(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ConsumptionPainter extends CustomPainter {
  const _ConsumptionPainter({
    required this.buckets,
    required this.color,
    required this.trackColor,
    required this.textColor,
    required this.textDirection,
  });

  final List<ConsumptionBucket> buckets;
  final Color color;
  final Color trackColor;
  final Color textColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 26;
    final width = size.width / math.max(buckets.length, 1);
    final maxValue = buckets.fold<double>(
      0,
      (maximum, bucket) => math.max(maximum, bucket.quantity),
    );
    final barPaint = Paint()..color = color;
    final emptyPaint = Paint()..color = trackColor;
    final textPainter = TextPainter(textDirection: textDirection);

    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      final barHeight = maxValue == 0
          ? 0.0
          : chartHeight * bucket.quantity / maxValue;
      final left = index * width + width * .18;
      if (barHeight == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, chartHeight - 4, width * .64, 4),
            const Radius.circular(4),
          ),
          emptyPaint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              left,
              chartHeight - barHeight,
              width * .64,
              barHeight,
            ),
            const Radius.circular(5),
          ),
          barPaint,
        );
      }
      textPainter.text = TextSpan(
        text: bucket.label,
        style: TextStyle(fontSize: 10, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          index * width + (width - textPainter.width) / 2,
          chartHeight + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConsumptionPainter oldDelegate) =>
      oldDelegate.buckets != buckets;
}
