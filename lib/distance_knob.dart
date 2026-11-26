import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'branch_status.dart';

// The biggest circle the customer can pick, in km.
const maxRadiusKm = 40;

// How big the round knob is on screen.
const knobSize = 88.0;

// A round knob for the circle size: turn it clockwise for more km and
// anticlockwise for less, one km at a time (one full turn = 40 km).
// The − and + buttons change it by one km too.
class DistanceKnob extends StatefulWidget {
  const DistanceKnob({super.key, required this.km, required this.onChanged});

  final int km;
  final void Function(int km) onChanged;

  @override
  State<DistanceKnob> createState() => _DistanceKnobState();
}

class _DistanceKnobState extends State<DistanceKnob> {
  static const stepAngle = 2 * pi / maxRadiusKm; // 9° = one km
  double _lastAngle = 0; // where the finger was, as an angle
  double _turned = 0; // how far it turned since the last km step

  // The finger's angle around the knob's center.
  double angleOf(Offset point) {
    return atan2(point.dy - knobSize / 2, point.dx - knobSize / 2);
  }

  // Sets a new km between 1 and 40, with a small tick on the phone.
  void change(int km) {
    final next = km.clamp(1, maxRadiusKm);
    if (next == widget.km) return;
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  // Every 9° the finger turns adds (clockwise) or removes one km.
  void onTurn(DragUpdateDetails details) {
    final angle = angleOf(details.localPosition);
    var delta = angle - _lastAngle;
    // Crossing the left side jumps from +180° to −180°; undo that jump.
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    _lastAngle = angle;
    _turned += delta;
    final steps = _turned ~/ stepAngle; // whole km, keeps the sign
    if (steps == 0) return;
    _turned -= steps * stepAngle;
    change(widget.km + steps);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'أقل',
          onPressed: widget.km > 1 ? () => change(widget.km - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        GestureDetector(
          onPanStart: (details) {
            _lastAngle = angleOf(details.localPosition);
            _turned = 0;
          },
          onPanUpdate: onTurn,
          child: CustomPaint(
            painter: _KnobPainter(
              part: widget.km / maxRadiusKm,
              track: theme.colorScheme.outlineVariant,
              fill: theme.colorScheme.primary,
            ),
            child: SizedBox.square(
              dimension: knobSize,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    arabicDigits('${widget.km}'),
                    style: theme.textTheme.titleLarge,
                  ),
                  Text('كم', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'أكثر',
          onPressed: widget.km < maxRadiusKm
              ? () => change(widget.km + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

// Draws the knob: a grey ring, a colored arc from the top for how much of
// the 40 km is picked, and a dot at the arc's end to grab.
class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.part, required this.track, required this.fill});

  final double part; // 0…1
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ring..color = track);
    final sweep = 2 * pi * part;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start at the top
      sweep,
      false,
      ring..color = fill,
    );
    final end = center + Offset.fromDirection(-pi / 2 + sweep, radius);
    canvas.drawCircle(end, 8, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.part != part;
}
