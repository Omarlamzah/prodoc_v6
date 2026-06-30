// lib/screens/image_annotation_screen.dart
// Enhanced Medical Image Annotation — ProDoc
// Features: finding counter, timestamps, severity coding, angle measurement,
//           area calculation, annotation comments, density stamps,
//           findings summary export, second opinion mode, before/after split view

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

enum AnnotationTool {
  select,
  freeStyle,
  line,
  rect,
  circle,
  arrow,
  text,
  eraser,
  roi,
  measure,
  angle,    // NEW: 3-point angle
  stamp,    // NEW: preset density/finding labels
}

enum Severity { normal, suspicious, critical }

enum AnnotationLayer { doctor1, doctor2 }

extension SeverityExt on Severity {
  Color get color {
    switch (this) {
      case Severity.normal:     return const Color(0xFF22C55E);
      case Severity.suspicious: return const Color(0xFFF59E0B);
      case Severity.critical:   return const Color(0xFFEF4444);
    }
  }
  String get label {
    switch (this) {
      case Severity.normal:     return 'Normal';
      case Severity.suspicious: return 'Suspicious';
      case Severity.critical:   return 'Critical';
    }
  }
  IconData get icon {
    switch (this) {
      case Severity.normal:     return Icons.check_circle_rounded;
      case Severity.suspicious: return Icons.warning_amber_rounded;
      case Severity.critical:   return Icons.dangerous_rounded;
    }
  }
}

// Preset stamp labels grouped by specialty (for text stamps)
const Map<String, List<String>> kStampPresets = {
  'Radiology': [
    'Hyperdense', 'Hypodense', 'Calcified', 'Consolidation',
    'Ground-glass', 'Pleural effusion', 'Atelectasis', 'Pneumothorax',
  ],
  'Orthopedics': [
    'Fracture', 'Dislocation', 'Osteophyte', 'Joint space narrowing',
    'Periosteal reaction', 'Cortical breach', 'Bone lesion',
  ],
  'Dermatology': [
    'Melanoma suspect', 'Basal cell', 'Nevus', 'Ulceration',
    'Keratosis', 'Erythema', 'Induration',
  ],
  'Ophthalmology': [
    'Drusen', 'CNV', 'Macular edema', 'Disc pallor',
    'Cup enlargement', 'Retinal detachment', 'Haemorrhage',
  ],
};

// Annotation templates: pre-configured shapes placed with one tap
enum _TemplateShape { ellipse, rect, arrow }

class AnnotationTemplate {
  final String name;
  final String label;
  final _TemplateShape shape;
  final Color color;
  final Severity severity;
  /// Size in logical pixels (width, height for ellipse/rect; ignored for arrow)
  final Size size;

  const AnnotationTemplate({
    required this.name,
    required this.label,
    required this.shape,
    required this.color,
    required this.severity,
    required this.size,
  });
}

const List<AnnotationTemplate> kAnnotationTemplates = [
  AnnotationTemplate(name: 'Lesion ROI',     label: 'Lesion',     shape: _TemplateShape.ellipse, color: Color(0xFFEF4444), severity: Severity.suspicious, size: Size(80, 60)),
  AnnotationTemplate(name: 'Mass ROI',       label: 'Mass',       shape: _TemplateShape.ellipse, color: Color(0xFFEF4444), severity: Severity.critical,   size: Size(100, 80)),
  AnnotationTemplate(name: 'Lymph node',     label: 'LN',         shape: _TemplateShape.ellipse, color: Color(0xFFF59E0B), severity: Severity.suspicious, size: Size(40, 30)),
  AnnotationTemplate(name: 'Highlight box',  label: 'Region',     shape: _TemplateShape.rect,    color: Color(0xFF3B82F6), severity: Severity.normal,     size: Size(100, 70)),
  AnnotationTemplate(name: 'Critical area',  label: 'CRITICAL',   shape: _TemplateShape.rect,    color: Color(0xFFEF4444), severity: Severity.critical,   size: Size(90, 60)),
  AnnotationTemplate(name: 'Point of interest', label: 'POI',     shape: _TemplateShape.arrow,   color: Color(0xFF22C55E), severity: Severity.normal,     size: Size(60, 0)),
];

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

int _findingCounter = 0;
int _nextFindingNumber() => ++_findingCounter;

abstract class AnnotationShape {
  final String id;
  final int findingNumber;
  final DateTime timestamp;
  Color color;
  double strokeWidth;
  Severity severity;
  String comment;
  AnnotationLayer layer;

  AnnotationShape({
    required this.id,
    required this.color,
    required this.strokeWidth,
    this.severity = Severity.normal,
    this.comment = '',
    this.layer = AnnotationLayer.doctor1,
  })  : findingNumber = _nextFindingNumber(),
        timestamp = DateTime.now();

  AnnotationShape copyWith();

  String get typeLabel;

  String get summaryLine {
    final ts = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final sev = severity == Severity.normal ? '' : ' [${severity.label}]';
    final cmt = comment.isNotEmpty ? ' — "$comment"' : '';
    return 'Finding $findingNumber ($ts)$sev: $typeLabel$cmt';
  }
}

// ── Shape subclasses ──────────────────────────────────────────────────────────

class FreeStyleShape extends AnnotationShape {
  List<Offset> points;
  double? areaMm2; // calculated after calibration
  FreeStyleShape({
    required super.id, required super.color, required super.strokeWidth,
    required this.points, super.severity, super.comment, super.layer,
  });
  @override FreeStyleShape copyWith() => FreeStyleShape(id: id, color: color, strokeWidth: strokeWidth, points: List.of(points), severity: severity, comment: comment, layer: layer);
  @override String get typeLabel {
    if (areaMm2 != null) return 'Freehand ROI — ${areaMm2!.toStringAsFixed(1)} mm²';
    return 'Freehand drawing';
  }
}

class LineShape extends AnnotationShape {
  Offset p1, p2;
  LineShape({required super.id, required super.color, required super.strokeWidth, required this.p1, required this.p2, super.severity, super.comment, super.layer});
  @override LineShape copyWith() => LineShape(id: id, color: color, strokeWidth: strokeWidth, p1: p1, p2: p2, severity: severity, comment: comment, layer: layer);
  @override String get typeLabel => 'Line';
}

class RectShape extends AnnotationShape {
  Rect rect;
  RectShape({required super.id, required super.color, required super.strokeWidth, required this.rect, super.severity, super.comment, super.layer});
  @override RectShape copyWith() => RectShape(id: id, color: color, strokeWidth: strokeWidth, rect: rect, severity: severity, comment: comment, layer: layer);
  @override String get typeLabel => 'Rectangle';
}

class CircleShape extends AnnotationShape {
  Rect bounds;
  CircleShape({required super.id, required super.color, required super.strokeWidth, required this.bounds, super.severity, super.comment, super.layer});
  @override CircleShape copyWith() => CircleShape(id: id, color: color, strokeWidth: strokeWidth, bounds: bounds, severity: severity, comment: comment, layer: layer);
  @override String get typeLabel => 'Circle';
}

class ArrowShape extends AnnotationShape {
  Offset p1, p2;
  ArrowShape({required super.id, required super.color, required super.strokeWidth, required this.p1, required this.p2, super.severity, super.comment, super.layer});
  @override ArrowShape copyWith() => ArrowShape(id: id, color: color, strokeWidth: strokeWidth, p1: p1, p2: p2, severity: severity, comment: comment, layer: layer);
  @override String get typeLabel => 'Arrow';
}

class TextShape extends AnnotationShape {
  String text;
  Offset position;
  double fontSize;
  TextShape({required super.id, required super.color, required super.strokeWidth, required this.text, required this.position, required this.fontSize, super.severity, super.comment, super.layer});
  @override TextShape copyWith() => TextShape(id: id, color: color, strokeWidth: strokeWidth, text: text, position: position, fontSize: fontSize, severity: severity, comment: comment, layer: layer);
  @override String get typeLabel => 'Text: "$text"';
}

class RoiShape extends AnnotationShape {
  Rect bounds;
  String label;
  RoiShape({required super.id, required super.color, required super.strokeWidth, required this.bounds, required this.label, super.severity, super.comment, super.layer});
  @override RoiShape copyWith() => RoiShape(id: id, color: color, strokeWidth: strokeWidth, bounds: bounds, label: label, severity: severity, comment: comment, layer: layer);
  @override String get typeLabel => label.isNotEmpty ? 'ROI: $label' : 'Region of interest';
}

class MeasureShape extends AnnotationShape {
  Offset p1, p2;
  double? pxPerMm; // calibration ratio at time of drawing

  MeasureShape({required super.id, required super.color, required super.strokeWidth, required this.p1, required this.p2, this.pxPerMm, super.severity, super.comment, super.layer});
  @override MeasureShape copyWith() => MeasureShape(id: id, color: color, strokeWidth: strokeWidth, p1: p1, p2: p2, pxPerMm: pxPerMm, severity: severity, comment: comment, layer: layer);

  double get pixelLength => (p2 - p1).distance;

  /// Returns calibrated mm value, or null if not calibrated.
  double? get mmValue => pxPerMm != null && pxPerMm! > 0 ? pixelLength / pxPerMm! : null;

  String displayLabel({double? livePxPerMm}) {
    final ratio = livePxPerMm ?? pxPerMm;
    if (ratio != null && ratio > 0) {
      final mm = pixelLength / ratio;
      return '${mm.toStringAsFixed(1)} mm';
    }
    return '${pixelLength.toStringAsFixed(0)} px';
  }

  @override String get typeLabel {
    final mm = mmValue;
    return mm != null ? 'Measurement: ${mm.toStringAsFixed(1)} mm' : 'Measurement: ${pixelLength.toStringAsFixed(0)} px';
  }
}

class AngleShape extends AnnotationShape {
  Offset p1, vertex, p2; // vertex is the corner point
  AngleShape({required super.id, required super.color, required super.strokeWidth, required this.p1, required this.vertex, required this.p2, super.severity, super.comment, super.layer});
  @override AngleShape copyWith() => AngleShape(id: id, color: color, strokeWidth: strokeWidth, p1: p1, vertex: vertex, p2: p2, severity: severity, comment: comment, layer: layer);

  double get degrees {
    final v1 = p1 - vertex;
    final v2 = p2 - vertex;
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final mag1 = v1.distance;
    final mag2 = v2.distance;
    if (mag1 == 0 || mag2 == 0) return 0;
    return (math.acos((dot / (mag1 * mag2)).clamp(-1.0, 1.0)) * 180 / math.pi);
  }

  @override String get typeLabel => 'Angle: ${degrees.toStringAsFixed(1)}°';
}

class StampShape extends AnnotationShape {
  String label;
  Offset position;
  StampShape({required super.id, required super.color, required super.strokeWidth, required this.label, required this.position, super.severity, super.comment, super.layer});
  @override StampShape copyWith() => StampShape(id: id, color: color, strokeWidth: strokeWidth, label: label, position: position, severity: severity, comment: comment, layer: layer);
  @override String get typeLabel => 'Stamp: $label';
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _AnnotationPainter extends CustomPainter {
  final ui.Image? bgImage;
  final ui.Image? bgImage2; // for split view
  final List<AnnotationShape> shapes;
  final AnnotationShape? previewShape;
  final String? selectedId;
  final bool showDoctor1;
  final bool showDoctor2;
  final double splitFraction; // 0.0–1.0 for before/after split

  const _AnnotationPainter({
    required this.bgImage,
    required this.shapes,
    this.bgImage2,
    this.previewShape,
    this.selectedId,
    this.showDoctor1 = true,
    this.showDoctor2 = true,
    this.splitFraction = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Background ──
    if (bgImage2 != null && splitFraction < 1.0) {
      // Before (left side)
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * splitFraction, size.height));
      if (bgImage != null) {
        canvas.drawImageRect(bgImage!, Rect.fromLTWH(0, 0, bgImage!.width.toDouble(), bgImage!.height.toDouble()),
            Rect.fromLTWH(0, 0, size.width, size.height), Paint());
      }
      // "Before" label
      _drawSplitLabel(canvas, 'Before', Offset(8, 8), size, isLeft: true);
      canvas.restore();
      // After (right side)
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(size.width * splitFraction, 0, size.width * (1 - splitFraction), size.height));
      canvas.drawImageRect(bgImage2!, Rect.fromLTWH(0, 0, bgImage2!.width.toDouble(), bgImage2!.height.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height), Paint());
      _drawSplitLabel(canvas, 'After', Offset(size.width - 60, 8), size, isLeft: false);
      canvas.restore();
      // Split divider line
      final divX = size.width * splitFraction;
      canvas.drawLine(Offset(divX, 0), Offset(divX, size.height),
          Paint()..color = Colors.white..strokeWidth = 2);
      // Handle circle
      canvas.drawCircle(Offset(divX, size.height / 2), 16,
          Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(divX, size.height / 2), 16,
          Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);
      final iconPaint = Paint()..color = Colors.black..strokeWidth = 2..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(divX - 6, size.height / 2), Offset(divX - 10, size.height / 2 - 5), iconPaint);
      canvas.drawLine(Offset(divX - 6, size.height / 2), Offset(divX - 10, size.height / 2 + 5), iconPaint);
      canvas.drawLine(Offset(divX + 6, size.height / 2), Offset(divX + 10, size.height / 2 - 5), iconPaint);
      canvas.drawLine(Offset(divX + 6, size.height / 2), Offset(divX + 10, size.height / 2 + 5), iconPaint);
    } else {
      if (bgImage != null) {
        canvas.drawImageRect(bgImage!, Rect.fromLTWH(0, 0, bgImage!.width.toDouble(), bgImage!.height.toDouble()),
            Rect.fromLTWH(0, 0, size.width, size.height), Paint());
      } else {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black);
      }
    }

    // ── Shapes ──
    for (final s in shapes) {
      if (s.layer == AnnotationLayer.doctor1 && !showDoctor1) continue;
      if (s.layer == AnnotationLayer.doctor2 && !showDoctor2) continue;
      _drawShape(canvas, s, s.id == selectedId);
    }
    if (previewShape != null) _drawShape(canvas, previewShape!, false);
  }

  void _drawSplitLabel(Canvas canvas, String text, Offset pos, Size size, {required bool isLeft}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx - 4, pos.dy - 2, tp.width + 8, tp.height + 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(bgRect, Paint()..color = Colors.black54);
    tp.paint(canvas, pos);
  }

  void _drawShape(Canvas canvas, AnnotationShape shape, bool selected) {
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── FreeStyle ──
    if (shape is FreeStyleShape && shape.points.length >= 2) {
      final path = Path()..moveTo(shape.points.first.dx, shape.points.first.dy);
      for (final p in shape.points.skip(1)) path.lineTo(p.dx, p.dy);
      canvas.drawPath(path, paint);
      if (shape.areaMm2 != null) {
        final center = _polyCenter(shape.points);
        _drawLabelPill(canvas, '${shape.areaMm2!.toStringAsFixed(1)} mm²', center, shape.color);
      }

    // ── Line ──
    } else if (shape is LineShape) {
      canvas.drawLine(shape.p1, shape.p2, paint);

    // ── Rect ──
    } else if (shape is RectShape) {
      canvas.drawRect(shape.rect, paint);

    // ── Circle ──
    } else if (shape is CircleShape) {
      canvas.drawOval(shape.bounds, paint);

    // ── Arrow ──
    } else if (shape is ArrowShape) {
      canvas.drawLine(shape.p1, shape.p2, paint);
      _drawArrowHead(canvas, shape.p1, shape.p2, paint);

    // ── Text ──
    } else if (shape is TextShape) {
      final tp = TextPainter(
        text: TextSpan(
          text: shape.text,
          style: TextStyle(color: shape.color, fontSize: shape.fontSize, fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, shape.position);

    // ── ROI ──
    } else if (shape is RoiShape) {
      canvas.drawOval(shape.bounds, Paint()..color = shape.color.withOpacity(0.2)..style = PaintingStyle.fill);
      _drawDashedOval(canvas, shape.bounds, paint..color = shape.color..strokeWidth = 2);
      if (shape.label.isNotEmpty) {
        _drawLabelPill(canvas, shape.label, Offset(shape.bounds.center.dx, shape.bounds.top - 14), shape.color);
      }

    // ── Measure ──
    } else if (shape is MeasureShape) {
      _drawDashedLine(canvas, shape.p1, shape.p2, paint..color = shape.color..strokeWidth = 2);
      _drawMeasureTick(canvas, shape.p1, shape.p2, paint);
      _drawMeasureTick(canvas, shape.p2, shape.p1, paint);
      _drawLabelPill(canvas, shape.displayLabel(), (shape.p1 + shape.p2) / 2 - const Offset(0, 14), shape.color);

    // ── Angle ──
    } else if (shape is AngleShape) {
      canvas.drawLine(shape.vertex, shape.p1, paint);
      canvas.drawLine(shape.vertex, shape.p2, paint);
      // Arc
      final r = 28.0;
      final a1 = math.atan2(shape.p1.dy - shape.vertex.dy, shape.p1.dx - shape.vertex.dx);
      final a2 = math.atan2(shape.p2.dy - shape.vertex.dy, shape.p2.dx - shape.vertex.dx);
      final arcRect = Rect.fromCenter(center: shape.vertex, width: r * 2, height: r * 2);
      canvas.drawArc(arcRect, math.min(a1, a2), (a2 - a1).abs().clamp(0, math.pi * 2), false,
          paint..strokeWidth = 1.5);
      // Endpoint dots
      canvas.drawCircle(shape.p1, 4, Paint()..color = shape.color..style = PaintingStyle.fill);
      canvas.drawCircle(shape.p2, 4, Paint()..color = shape.color..style = PaintingStyle.fill);
      canvas.drawCircle(shape.vertex, 5, Paint()..color = shape.color..style = PaintingStyle.fill);
      // Label
      final mid = shape.vertex + Offset(r * math.cos((a1 + a2) / 2) * 1.6, r * math.sin((a1 + a2) / 2) * 1.6);
      _drawLabelPill(canvas, '${shape.degrees.toStringAsFixed(1)}°', mid, shape.color);

    // ── Stamp ──
    } else if (shape is StampShape) {
      final bg = shape.color.withOpacity(0.15);
      final tp = TextPainter(
        text: TextSpan(
          text: '● ${shape.label}',
          style: TextStyle(color: shape.color, fontSize: 13, fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      const px = 8.0, py = 4.0;
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(shape.position.dx - px, shape.position.dy - tp.height - py,
            tp.width + px * 2, tp.height + py * 2),
        const Radius.circular(6),
      );
      canvas.drawRRect(pillRect, Paint()..color = bg..style = PaintingStyle.fill);
      canvas.drawRRect(pillRect, paint..color = shape.color..strokeWidth = 1.5);
      tp.paint(canvas, Offset(shape.position.dx, shape.position.dy - tp.height));
    }

    // ── Finding number badge ──
    _drawFindingBadge(canvas, shape);

    // ── Severity indicator ──
    if (shape.severity != Severity.normal) {
      _drawSeverityDot(canvas, shape);
    }

    // ── Comment indicator ──
    if (shape.comment.isNotEmpty) {
      _drawCommentIndicator(canvas, shape);
    }

    // ── Selection highlight ──
    if (selected) {
      if (shape is AngleShape) {
        final handleFill = Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill;
        final handleStroke = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
        for (final pt in [shape.p1, shape.vertex, shape.p2]) {
          canvas.drawCircle(pt, 10, handleFill);
          canvas.drawCircle(pt, 10, handleStroke);
        }
      } else if (shape is MeasureShape) {
        final handleFill = Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill;
        final handleStroke = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
        for (final pt in [shape.p1, shape.p2]) {
          canvas.drawCircle(pt, 10, handleFill);
          canvas.drawCircle(pt, 10, handleStroke);
        }
      } else {
        final bb = _getBoundingBox(shape);
        if (bb != null) {
          final selPaint = Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 2..style = PaintingStyle.stroke;
          final expanded = bb.inflate(8);
          _drawDashedRect(canvas, expanded, selPaint);
          final handlePaint = Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill;
          for (final corner in [expanded.topLeft, expanded.topRight, expanded.bottomLeft, expanded.bottomRight]) {
            canvas.drawCircle(corner, 5, handlePaint);
          }
        }
      }
    }
  }

  void _drawFindingBadge(Canvas canvas, AnnotationShape shape) {
    final anchor = _getBadgeAnchor(shape);
    if (anchor == null) return;
    final label = '${shape.findingNumber}';
    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    const r = 11.0;
    canvas.drawCircle(anchor, r, Paint()..color = const Color(0xFF1E3A5F)..style = PaintingStyle.fill);
    canvas.drawCircle(anchor, r, Paint()..color = Colors.white.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1);
    tp.paint(canvas, anchor - Offset(tp.width / 2, tp.height / 2));
  }

  Offset? _getBadgeAnchor(AnnotationShape shape) {
    if (shape is FreeStyleShape && shape.points.isNotEmpty) return shape.points.first - const Offset(0, 14);
    if (shape is LineShape) return shape.p1 - const Offset(0, 14);
    if (shape is RectShape) return shape.rect.topLeft - const Offset(0, 14);
    if (shape is CircleShape) return shape.bounds.topLeft - const Offset(0, 14);
    if (shape is ArrowShape) return shape.p1 - const Offset(0, 14);
    if (shape is TextShape) return shape.position - const Offset(0, 14);
    if (shape is RoiShape) return shape.bounds.topRight + const Offset(6, -6);
    if (shape is MeasureShape) return shape.p1 - const Offset(0, 14);
    if (shape is AngleShape) return shape.vertex - const Offset(0, 22);
    if (shape is StampShape) return shape.position - const Offset(0, 28);
    return null;
  }

  void _drawSeverityDot(Canvas canvas, AnnotationShape shape) {
    final anchor = _getBadgeAnchor(shape);
    if (anchor == null) return;
    final dotPos = anchor + const Offset(14, 0);
    canvas.drawCircle(dotPos, 6, Paint()..color = shape.severity.color..style = PaintingStyle.fill);
    canvas.drawCircle(dotPos, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  void _drawCommentIndicator(Canvas canvas, AnnotationShape shape) {
    final anchor = _getBadgeAnchor(shape);
    if (anchor == null) return;
    final dotPos = anchor + const Offset(28, 0);
    canvas.drawCircle(dotPos, 5, Paint()..color = const Color(0xFF8B5CF6)..style = PaintingStyle.fill);
    // "..." text
    final tp = TextPainter(
      text: const TextSpan(text: '✎', style: TextStyle(color: Colors.white, fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, dotPos - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dx = to.dx - from.dx, dy = to.dy - from.dy;
    final angle = math.atan2(dy, dx);
    final hl = paint.strokeWidth * 4 + 12;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - hl * math.cos(angle - math.pi / 6), to.dy - hl * math.sin(angle - math.pi / 6))
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - hl * math.cos(angle + math.pi / 6), to.dy - hl * math.sin(angle + math.pi / 6));
    canvas.drawPath(path, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 8.0, gapLen = 5.0;
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final total = math.sqrt(dx * dx + dy * dy);
    if (total == 0) return;
    final ux = dx / total, uy = dy / total;
    double d = 0; bool drawing = true;
    while (d < total) {
      final segLen = drawing ? math.min(dashLen, total - d) : math.min(gapLen, total - d);
      if (drawing) {
        canvas.drawLine(Offset(p1.dx + ux * d, p1.dy + uy * d),
            Offset(p1.dx + ux * (d + segLen), p1.dy + uy * (d + segLen)), paint);
      }
      d += segLen; drawing = !drawing;
    }
  }

  void _drawDashedOval(Canvas canvas, Rect bounds, Paint paint) {
    const steps = 64;
    final cx = bounds.center.dx, cy = bounds.center.dy;
    final rx = bounds.width / 2, ry = bounds.height / 2;
    bool drawing = true; int dashCount = 0; Offset? prev;
    for (int i = 0; i <= steps; i++) {
      final angle = 2 * math.pi * i / steps;
      final pt = Offset(cx + rx * math.cos(angle), cy + ry * math.sin(angle));
      if (i == 0) { prev = pt; continue; }
      if (drawing) canvas.drawLine(prev!, pt, paint);
      dashCount++;
      if (dashCount >= 4) { drawing = !drawing; dashCount = 0; }
      prev = pt;
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawMeasureTick(Canvas canvas, Offset at, Offset other, Paint paint) {
    final dx = other.dx - at.dx, dy = other.dy - at.dy;
    final angle = math.atan2(dy, dx);
    const h = 10.0;
    canvas.drawLine(
      Offset(at.dx + h * math.cos(angle + math.pi / 2), at.dy + h * math.sin(angle + math.pi / 2)),
      Offset(at.dx + h * math.cos(angle - math.pi / 2), at.dy + h * math.sin(angle - math.pi / 2)),
      paint,
    );
  }

  void _drawLabelPill(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    const px = 6.0, py = 3.0;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tp.width + px * 2, height: tp.height + py * 2),
      const Radius.circular(4),
    );
    canvas.drawRRect(pillRect, Paint()..color = Colors.black.withOpacity(0.7)..style = PaintingStyle.fill);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  Offset _polyCenter(List<Offset> points) {
    double cx = 0, cy = 0;
    for (final p in points) { cx += p.dx; cy += p.dy; }
    return Offset(cx / points.length, cy / points.length);
  }

  Rect? _getBoundingBox(AnnotationShape shape) {
    if (shape is FreeStyleShape && shape.points.isNotEmpty) {
      final xs = shape.points.map((p) => p.dx); final ys = shape.points.map((p) => p.dy);
      return Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
    }
    if (shape is LineShape) return Rect.fromPoints(shape.p1, shape.p2);
    if (shape is RectShape) return shape.rect;
    if (shape is CircleShape) return shape.bounds;
    if (shape is ArrowShape) return Rect.fromPoints(shape.p1, shape.p2);
    if (shape is TextShape) return Rect.fromLTWH(shape.position.dx, shape.position.dy - shape.fontSize, 80, shape.fontSize + 4);
    if (shape is RoiShape) return shape.bounds;
    if (shape is MeasureShape) return Rect.fromPoints(shape.p1, shape.p2);
    if (shape is AngleShape) {
      final pts = [shape.p1, shape.vertex, shape.p2];
      return Rect.fromLTRB(pts.map((p) => p.dx).reduce(math.min), pts.map((p) => p.dy).reduce(math.min),
          pts.map((p) => p.dx).reduce(math.max), pts.map((p) => p.dy).reduce(math.max));
    }
    if (shape is StampShape) return Rect.fromLTWH(shape.position.dx - 8, shape.position.dy - 22, 120, 22);
    return null;
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ImageAnnotationScreen extends StatefulWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;
  final String fileName;

  // Optional: second image for before/after comparison
  final Uint8List? imageBytes2;
  final String? imageUrl2;

  const ImageAnnotationScreen({
    super.key,
    this.imageBytes,
    this.imageUrl,
    required this.fileName,
    this.imageBytes2,
    this.imageUrl2,
  }) : assert(imageBytes != null || imageUrl != null);

  @override
  State<ImageAnnotationScreen> createState() => _ImageAnnotationScreenState();
}

class _ImageAnnotationScreenState extends State<ImageAnnotationScreen>
    with TickerProviderStateMixin {
  // Images
  ui.Image? _bgImage;
  ui.Image? _bgImage2;
  bool _imageLoading = true;

  // Tools & style
  AnnotationTool _tool = AnnotationTool.freeStyle;
  Color _color = Colors.red;
  double _strokeWidth = 4.0;
  Severity _severity = Severity.normal;
  AnnotationLayer _activeLayer = AnnotationLayer.doctor1;

  // Shapes
  final List<AnnotationShape> _shapes = [];
  final List<List<AnnotationShape>> _undoStack = [];
  final List<List<AnnotationShape>> _redoStack = [];

  AnnotationShape? _previewShape;
  String? _selectedId;

  // Drawing state
  bool _isDrawing = false;
  Offset _startPt = Offset.zero;
  // Angle tool: 0 = placing vertex, 1 = placing p1, 2 = placing p2
  int _angleStep = 0;
  Offset? _angleVertex;
  Offset? _angleP1;

  // Select / drag
  bool _isDragging = false;
  Offset _dragMouseStart = Offset.zero;
  AnnotationShape? _dragShapeSnapshot;
  String? _draggingEndpoint; // 'p1','p2','vertex'

  // Zoom
  double _zoom = 1.0;
  final TransformationController _transformController = TransformationController();

  // Second opinion layers
  bool _showDoctor1 = true;
  bool _showDoctor2 = true;

  // Split view
  double _splitFraction = 0.5;
  bool _isDraggingSplit = false;

  // Calibration: pixels per millimetre (null = not calibrated yet)
  double? _pxPerMm;

  bool _isSaving = false;
  String _selectedSpecialty = 'Radiology';

  // Tab controller for toolbar tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _findingCounter = 0;
    _tabController = TabController(length: 3, vsync: this);
    _loadImages();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Image loading ────────────────────────────────────────────────────────────

  Future<void> _loadImages() async {
    setState(() => _imageLoading = true);
    try {
      _bgImage = await _loadSingleImage(widget.imageBytes, widget.imageUrl);
      if (widget.imageBytes2 != null || widget.imageUrl2 != null) {
        _bgImage2 = await _loadSingleImage(widget.imageBytes2, widget.imageUrl2);
      }
      if (mounted) setState(() => _imageLoading = false);
    } catch (_) {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  Future<ui.Image?> _loadSingleImage(Uint8List? bytes, String? url) async {
    if (bytes != null) {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    }
    if (url != null) {
      final b = await _fetchNetworkBytes(url);
      final codec = await ui.instantiateImageCodec(b);
      final frame = await codec.getNextFrame();
      return frame.image;
    }
    return null;
  }

  Future<Uint8List> _fetchNetworkBytes(String url) async {
    final completer = Completer<Uint8List>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) async {
        stream.removeListener(listener);
        final bd = await info.image.toByteData(format: ui.ImageByteFormat.png);
        completer.complete(bd!.buffer.asUint8List());
      },
      onError: (e, st) { stream.removeListener(listener); completer.completeError(e, st); },
    );
    stream.addListener(listener);
    return completer.future;
  }

  // ── History ──────────────────────────────────────────────────────────────────

  void _pushHistory() {
    _undoStack.add(_shapes.map((s) => s.copyWith()).toList());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_shapes.map((s) => s.copyWith()).toList());
    setState(() { _shapes..clear()..addAll(_undoStack.removeLast()); _selectedId = null; _previewShape = null; });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_shapes.map((s) => s.copyWith()).toList());
    setState(() { _shapes..clear()..addAll(_redoStack.removeLast()); _selectedId = null; _previewShape = null; });
  }

  // ── Shoelace area (in px²) ────────────────────────────────────────────────

  double _shoelaceArea(List<Offset> points) {
    if (points.length < 3) return 0;
    double area = 0;
    final n = points.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += points[i].dx * points[j].dy;
      area -= points[j].dx * points[i].dy;
    }
    return area.abs() / 2;
  }

  // ── Export findings summary ──────────────────────────────────────────────────

  void _showFindingsSummary() {
    final visibleShapes = _shapes.where((s) {
      if (s.layer == AnnotationLayer.doctor1 && !_showDoctor1) return false;
      if (s.layer == AnnotationLayer.doctor2 && !_showDoctor2) return false;
      return true;
    }).toList();

    if (visibleShapes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No annotations to export.')));
      return;
    }

    final fullText = _buildReportText(visibleShapes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  Text('Findings Report', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: fullText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report copied to clipboard'), backgroundColor: Colors.teal),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.tealAccent),
                    label: Text('Copy', style: GoogleFonts.poppins(color: Colors.tealAccent)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // close sheet first
                      _exportReportImage();
                    },
                    icon: const Icon(Icons.image_rounded, size: 16, color: Colors.amber),
                    label: Text('Export', style: GoogleFonts.poppins(color: Colors.amber)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: SelectableText(
                      fullText,
                      style: GoogleFonts.sourceCodePro(color: Colors.white70, fontSize: 12, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Per-finding cards
                  ...visibleShapes.map((s) => _FindingCard(shape: s)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pointer events ────────────────────────────────────────────────────────────

  String _newId() => '${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(99999)}';

  void _onPanStart(DragStartDetails d) {
    if (_bgImage == null) return;
    final pt = d.localPosition;

    // Split view drag — only activate when touching within 24px of the divider line
    if (_bgImage2 != null && _isSplitMode && _canvasSize != null) {
      final divX = _canvasSize!.width * _splitFraction;
      if ((pt.dx - divX).abs() <= 24) {
        _isDraggingSplit = true;
        return;
      }
    }

    // ── SELECT tool ──
    if (_tool == AnnotationTool.select) {
      // Check endpoint handles of selected shape
      if (_selectedId != null) {
        final sel = _shapes.firstWhere((s) => s.id == _selectedId, orElse: () => _shapes.first);
        const handleR = 18.0;
        if (sel is MeasureShape) {
          if ((pt - sel.p1).distance <= handleR) { _pushHistory(); setState(() { _draggingEndpoint = 'p1'; _isDragging = false; }); return; }
          if ((pt - sel.p2).distance <= handleR) { _pushHistory(); setState(() { _draggingEndpoint = 'p2'; _isDragging = false; }); return; }
        }
        if (sel is AngleShape) {
          if ((pt - sel.p1).distance <= handleR) { _pushHistory(); setState(() { _draggingEndpoint = 'p1'; _isDragging = false; }); return; }
          if ((pt - sel.p2).distance <= handleR) { _pushHistory(); setState(() { _draggingEndpoint = 'p2'; _isDragging = false; }); return; }
          if ((pt - sel.vertex).distance <= handleR) { _pushHistory(); setState(() { _draggingEndpoint = 'vertex'; _isDragging = false; }); return; }
        }
      }
      AnnotationShape? hit;
      for (int i = _shapes.length - 1; i >= 0; i--) {
        if (_hitTest(_shapes[i], pt)) { hit = _shapes[i]; break; }
      }
      // Tapping a measure's label pill → edit value; tap elsewhere on the line → just select/drag
      if (hit is MeasureShape) {
        final measure = hit;
        final labelCenter = (measure.p1 + measure.p2) / 2 - const Offset(0, 14);
        const pillHitW = 56.0, pillHitH = 22.0;
        final pillRect = Rect.fromCenter(center: labelCenter, width: pillHitW, height: pillHitH);
        if (pillRect.contains(pt)) {
          setState(() { _selectedId = measure.id; _isDragging = false; _dragShapeSnapshot = null; _draggingEndpoint = null; });
          _editMeasureValue(measure);
          return;
        }
        // Tapping the line/body — just select and allow drag
      }
      // Tapping already-selected shape → show properties dialog
      if (hit != null && hit.id == _selectedId) { _showShapeProperties(hit); return; }

      setState(() {
        _selectedId = hit?.id;
        _draggingEndpoint = null;
        if (hit != null) {
          _isDragging = true;
          _dragMouseStart = pt;
          _dragShapeSnapshot = hit.copyWith();
        } else {
          _isDragging = false;
          _dragShapeSnapshot = null;
        }
      });
      return;
    }

    // ── ERASER ──
    if (_tool == AnnotationTool.eraser) {
      _pushHistory();
      _eraseAt(pt);
      return;
    }

    // ── TEXT ──
    if (_tool == AnnotationTool.text) {
      _addTextAt(pt);
      return;
    }

    // ── STAMP ──
    if (_tool == AnnotationTool.stamp) {
      _showStampPicker(pt);
      return;
    }

    // ── ANGLE (multi-step) ──
    if (_tool == AnnotationTool.angle) {
      if (_angleStep == 0) {
        // First click: place vertex
        setState(() {
          _angleVertex = pt;
          _angleStep = 1;
          _previewShape = AngleShape(id: _newId(), color: _color, strokeWidth: _strokeWidth,
              p1: pt, vertex: pt, p2: pt, severity: _severity, layer: _activeLayer);
        });
      } else if (_angleStep == 1) {
        setState(() {
          _angleP1 = pt;
          _angleStep = 2;
          (_previewShape as AngleShape).p1 = pt;
        });
      } else {
        // Third click: commit
        final shape = _previewShape as AngleShape;
        shape.p2 = pt;
        _pushHistory();
        setState(() {
          _shapes.add(shape);
          _previewShape = null;
          _angleStep = 0;
          _angleVertex = null;
          _angleP1 = null;
        });
      }
      return;
    }

    // ── Drawing tools ──
    _isDrawing = true;
    _startPt = pt;
    _selectedId = null;

    setState(() {
      switch (_tool) {
        case AnnotationTool.freeStyle:
          _previewShape = FreeStyleShape(id: _newId(), color: _color, strokeWidth: _strokeWidth,
              points: [pt], severity: _severity, layer: _activeLayer);
        case AnnotationTool.line:
          _previewShape = LineShape(id: _newId(), color: _color, strokeWidth: _strokeWidth,
              p1: pt, p2: pt, severity: _severity, layer: _activeLayer);
        case AnnotationTool.rect:
          _previewShape = RectShape(id: _newId(), color: _color, strokeWidth: _strokeWidth,
              rect: Rect.fromPoints(pt, pt), severity: _severity, layer: _activeLayer);
        case AnnotationTool.circle:
          _previewShape = CircleShape(id: _newId(), color: _color, strokeWidth: _strokeWidth,
              bounds: Rect.fromPoints(pt, pt), severity: _severity, layer: _activeLayer);
        case AnnotationTool.arrow:
          _previewShape = ArrowShape(id: _newId(), color: _color, strokeWidth: _strokeWidth,
              p1: pt, p2: pt, severity: _severity, layer: _activeLayer);
        case AnnotationTool.roi:
          _previewShape = RoiShape(id: _newId(), color: _color, strokeWidth: 2,
              bounds: Rect.fromPoints(pt, pt), label: '', severity: _severity, layer: _activeLayer);
        case AnnotationTool.measure:
          _previewShape = MeasureShape(id: _newId(), color: _color, strokeWidth: 2,
              p1: pt, p2: pt, severity: _severity, layer: _activeLayer);
        default: _previewShape = null;
      }
    });
  }

  bool get _isSplitMode => _bgImage2 != null;

  void _onPanUpdate(DragUpdateDetails d) {
    final pt = d.localPosition;

    // Split divider drag
    if (_isSplitMode && _isDraggingSplit) {
      // Need canvas size — approximate from constraints
      // We'll handle this in LayoutBuilder, store size
      if (_canvasSize != null) {
        setState(() => _splitFraction = (pt.dx / _canvasSize!.width).clamp(0.1, 0.9));
      }
      return;
    }

    // Angle preview update
    if (_tool == AnnotationTool.angle && _previewShape is AngleShape) {
      setState(() {
        final a = _previewShape as AngleShape;
        if (_angleStep == 1) { a.p1 = pt; }
        else if (_angleStep == 2) { a.p2 = pt; }
      });
      return;
    }

    // Drag endpoint handle
    if (_tool == AnnotationTool.select && _draggingEndpoint != null && _selectedId != null) {
      final idx = _shapes.indexWhere((s) => s.id == _selectedId);
      if (idx != -1) {
        setState(() {
          final s = _shapes[idx];
          if (s is MeasureShape) {
            if (_draggingEndpoint == 'p1') s.p1 = pt; else s.p2 = pt;
          } else if (s is AngleShape) {
            if (_draggingEndpoint == 'p1') s.p1 = pt;
            else if (_draggingEndpoint == 'p2') s.p2 = pt;
            else s.vertex = pt;
          }
        });
      }
      return;
    }

    // Move selected shape
    if (_tool == AnnotationTool.select && _isDragging && _dragShapeSnapshot != null && _selectedId != null) {
      final dx = pt.dx - _dragMouseStart.dx, dy = pt.dy - _dragMouseStart.dy;
      final idx = _shapes.indexWhere((s) => s.id == _selectedId);
      if (idx != -1) setState(() => _applyDelta(_shapes[idx], _dragShapeSnapshot!, Offset(dx, dy)));
      return;
    }

    if (_tool == AnnotationTool.eraser) { _eraseAt(pt); return; }

    if (!_isDrawing || _previewShape == null) return;

    setState(() {
      final p = _previewShape!;
      if (p is FreeStyleShape) p.points.add(pt);
      else if (p is LineShape) p.p2 = pt;
      else if (p is RectShape) p.rect = Rect.fromPoints(_startPt, pt);
      else if (p is CircleShape) p.bounds = Rect.fromPoints(_startPt, pt);
      else if (p is ArrowShape) p.p2 = pt;
      else if (p is RoiShape) p.bounds = Rect.fromPoints(_startPt, pt);
      else if (p is MeasureShape) p.p2 = pt;
    });
  }

  Size? _canvasSize;

  void _applyDelta(AnnotationShape shape, AnnotationShape snapshot, Offset delta) {
    if (shape is FreeStyleShape && snapshot is FreeStyleShape) shape.points = snapshot.points.map((p) => p + delta).toList();
    else if (shape is LineShape && snapshot is LineShape) { shape.p1 = snapshot.p1 + delta; shape.p2 = snapshot.p2 + delta; }
    else if (shape is RectShape && snapshot is RectShape) shape.rect = snapshot.rect.shift(delta);
    else if (shape is CircleShape && snapshot is CircleShape) shape.bounds = snapshot.bounds.shift(delta);
    else if (shape is ArrowShape && snapshot is ArrowShape) { shape.p1 = snapshot.p1 + delta; shape.p2 = snapshot.p2 + delta; }
    else if (shape is TextShape && snapshot is TextShape) shape.position = snapshot.position + delta;
    else if (shape is RoiShape && snapshot is RoiShape) shape.bounds = snapshot.bounds.shift(delta);
    else if (shape is MeasureShape && snapshot is MeasureShape) { shape.p1 = snapshot.p1 + delta; shape.p2 = snapshot.p2 + delta; }
    else if (shape is AngleShape && snapshot is AngleShape) { shape.p1 = snapshot.p1 + delta; shape.p2 = snapshot.p2 + delta; shape.vertex = snapshot.vertex + delta; }
    else if (shape is StampShape && snapshot is StampShape) shape.position = snapshot.position + delta;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isSplitMode && _isDraggingSplit) { setState(() => _isDraggingSplit = false); return; }

    if (_tool == AnnotationTool.select && _draggingEndpoint != null) {
      setState(() => _draggingEndpoint = null);
      return;
    }
    if (_tool == AnnotationTool.select && _isDragging) {
      if (_dragShapeSnapshot != null) {
        _undoStack.add(_shapes.map((s) => s.id == _dragShapeSnapshot!.id ? _dragShapeSnapshot! : s.copyWith()).toList());
        _redoStack.clear();
      }
      setState(() { _isDragging = false; _dragShapeSnapshot = null; });
      return;
    }

    if (!_isDrawing || _previewShape == null) return;
    _isDrawing = false;
    final shape = _previewShape!;

    if (shape is RoiShape) { _askForRoiLabel(shape); return; }
    if (shape is MeasureShape) { _askForMeasureValue(shape); return; }

    // FreeStyle: calculate area, convert to mm² if calibrated
    if (shape is FreeStyleShape && shape.points.length > 5) {
      final areaPx = _shoelaceArea(shape.points);
      if (areaPx > 10) {
        if (_pxPerMm != null && _pxPerMm! > 0) {
          shape.areaMm2 = areaPx / (_pxPerMm! * _pxPerMm!);
        } else {
          shape.areaMm2 = null; // not calibrated — show nothing
        }
      }
    }

    _pushHistory();
    setState(() { _shapes.add(shape); _previewShape = null; });
  }

  bool _hitTest(AnnotationShape shape, Offset pt) {
    final bb = _getBB(shape);
    if (bb == null) return false;
    return bb.inflate(12).contains(pt);
  }

  void _eraseAt(Offset pt) {
    final r = _strokeWidth * 4;
    setState(() { _shapes.removeWhere((s) { final bb = _getBB(s); return bb != null && bb.inflate(r).contains(pt); }); });
  }

  Rect? _getBB(AnnotationShape shape) {
    if (shape is FreeStyleShape && shape.points.isNotEmpty) {
      final xs = shape.points.map((p) => p.dx); final ys = shape.points.map((p) => p.dy);
      return Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
    }
    if (shape is LineShape) return Rect.fromPoints(shape.p1, shape.p2);
    if (shape is RectShape) return shape.rect;
    if (shape is CircleShape) return shape.bounds;
    if (shape is ArrowShape) return Rect.fromPoints(shape.p1, shape.p2);
    if (shape is TextShape) return Rect.fromLTWH(shape.position.dx, shape.position.dy, 80, shape.fontSize);
    if (shape is RoiShape) return shape.bounds;
    if (shape is MeasureShape) return Rect.fromPoints(shape.p1, shape.p2);
    if (shape is AngleShape) {
      final pts = [shape.p1, shape.vertex, shape.p2];
      return Rect.fromLTRB(pts.map((p) => p.dx).reduce(math.min), pts.map((p) => p.dy).reduce(math.min),
          pts.map((p) => p.dx).reduce(math.max), pts.map((p) => p.dy).reduce(math.max));
    }
    if (shape is StampShape) return Rect.fromLTWH(shape.position.dx - 8, shape.position.dy - 22, 140, 26);
    return null;
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  void _addTextAt(Offset pt) async {
    final text = await _showSingleInputDialog('Add Text', 'e.g. Fracture, ROI, Lesion...', icon: Icons.text_fields_rounded);
    if (text == null || text.isEmpty) return;
    _pushHistory();
    setState(() {
      _shapes.add(TextShape(id: _newId(), color: _color, strokeWidth: _strokeWidth,
          text: text, position: pt, fontSize: _strokeWidth * 5 + 12, severity: _severity, layer: _activeLayer));
    });
  }

  void _showStampPicker(Offset pt) async {
    final textLabels = kStampPresets[_selectedSpecialty] ?? kStampPresets['Radiology']!;

    // Returns either AnnotationTemplate or String
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)))),
            // ── Shape templates ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text('Shape Templates', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: kAnnotationTemplates.map((t) => GestureDetector(
                onTap: () => Navigator.pop(context, t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.color.withOpacity(0.6)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      t.shape == _TemplateShape.ellipse ? Icons.circle_outlined
                          : t.shape == _TemplateShape.rect ? Icons.crop_square_rounded
                          : Icons.arrow_forward_rounded,
                      color: t.color, size: 14,
                    ),
                    const SizedBox(width: 6),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(t.name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      Text(t.severity.label, style: GoogleFonts.poppins(color: t.severity.color, fontSize: 9)),
                    ]),
                  ]),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade700),
            // ── Text labels ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const Icon(Icons.label_rounded, color: Colors.tealAccent, size: 16),
                const SizedBox(width: 6),
                Text('$_selectedSpecialty Labels', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: textLabels.map((s) => ActionChip(
                label: Text(s, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11)),
                backgroundColor: _color.withOpacity(0.15),
                side: BorderSide(color: _color.withOpacity(0.5)),
                onPressed: () => Navigator.pop(context, s),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (choice == null) return;
    _pushHistory();

    if (choice is AnnotationTemplate) {
      // Place a real pre-configured shape
      setState(() {
        switch (choice.shape) {
          case _TemplateShape.ellipse:
            _shapes.add(RoiShape(
              id: _newId(), color: choice.color, strokeWidth: 2,
              bounds: Rect.fromCenter(center: pt, width: choice.size.width, height: choice.size.height),
              label: choice.label, severity: choice.severity, layer: _activeLayer,
            ));
          case _TemplateShape.rect:
            _shapes.add(RectShape(
              id: _newId(), color: choice.color, strokeWidth: 2,
              rect: Rect.fromCenter(center: pt, width: choice.size.width, height: choice.size.height),
              severity: choice.severity, layer: _activeLayer,
            ));
          case _TemplateShape.arrow:
            _shapes.add(ArrowShape(
              id: _newId(), color: choice.color, strokeWidth: 3,
              p1: pt - Offset(choice.size.width, 0), p2: pt,
              severity: choice.severity, layer: _activeLayer,
            ));
        }
      });
    } else if (choice is String) {
      setState(() {
        _shapes.add(StampShape(id: _newId(), color: _color, strokeWidth: 2,
            label: choice, position: pt, severity: _severity, layer: _activeLayer));
      });
    }
  }

  Future<void> _askForRoiLabel(RoiShape shape) async {
    final label = await _showSingleInputDialog('ROI Label (optional)', 'e.g. Tumor, Cyst, Mass...', icon: Icons.highlight_rounded, confirmLabel: 'Add ROI');
    shape.label = label?.trim() ?? '';
    _pushHistory();
    setState(() { _shapes.add(shape); _previewShape = null; });
  }

  Future<void> _askForMeasureValue(MeasureShape shape) async {
    // If already calibrated, just assign the ratio and commit
    if (_pxPerMm != null) {
      shape.pxPerMm = _pxPerMm;
      _pushHistory();
      setState(() { _shapes.add(shape); _previewShape = null; });
      return;
    }
    // First time: ask user to calibrate using this line
    await _calibrateWithShape(shape);
    shape.pxPerMm = _pxPerMm;
    _pushHistory();
    setState(() { _shapes.add(shape); _previewShape = null; });
  }

  Future<void> _editMeasureValue(MeasureShape shape) async {
    // Let user re-calibrate or recalibrate just this shape
    await _calibrateWithShape(shape, isEdit: true);
    setState(() => shape.pxPerMm = _pxPerMm);
  }

  /// Shows a dialog asking "this line = ? mm" and sets _pxPerMm from the drawn pixel length.
  Future<void> _calibrateWithShape(MeasureShape shape, {bool isEdit = false}) async {
    final pxLen = shape.pixelLength;
    final ctrl = TextEditingController(
      text: (_pxPerMm != null && !isEdit) ? (pxLen / _pxPerMm!).toStringAsFixed(1) : '',
    );
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Row(children: [
          const Icon(Icons.straighten_rounded, color: Colors.tealAccent, size: 22),
          const SizedBox(width: 10),
          Text(_pxPerMm == null ? 'Calibrate scale' : 'Update calibration',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _pxPerMm == null
                ? 'How long is this line in real life?\nAll future measurements will use this scale.'
                : 'Enter the real-world length of this line to update the scale.',
            style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text('Line pixel length: ${pxLen.toStringAsFixed(0)} px',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl, autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.0', hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 22),
              suffixText: 'mm', suffixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.w600),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 1.5)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.pop(context, v);
            },
          ),
          const SizedBox(height: 8),
          Text('Leave empty to show pixel distance only.',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null),
              child: Text('Skip', style: TextStyle(color: Colors.grey.shade400))),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Set scale'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.pop(context, v);
            },
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() {
        _pxPerMm = pxLen / result;
        // Update all existing measures and freehand areas
        for (final s in _shapes) {
          if (s is MeasureShape) s.pxPerMm = _pxPerMm;
          if (s is FreeStyleShape && s.points.length > 5) {
            final areaPx = _shoelaceArea(s.points);
            if (areaPx > 10) s.areaMm2 = areaPx / (_pxPerMm! * _pxPerMm!);
          }
        }
      });
    }
  }

  void _resetCalibration() {
    setState(() {
      _pxPerMm = null;
      for (final s in _shapes) {
        if (s is MeasureShape) s.pxPerMm = null;
        if (s is FreeStyleShape) s.areaMm2 = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibration reset — draw a new line to re-calibrate'), backgroundColor: Colors.orange),
    );
  }

  Future<String?> _showSingleInputDialog(String title, String hint, {IconData? icon, String confirmLabel = 'Add'}) async {
    String input = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Row(children: [
          if (icon != null) ...[Icon(icon, color: Colors.blue, size: 20), const SizedBox(width: 8)],
          Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
          ),
          onChanged: (v) => input = v,
          onSubmitted: (_) => Navigator.pop(context, input),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400))),
          ElevatedButton(onPressed: () => Navigator.pop(context, input),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(confirmLabel)),
        ],
      ),
    );
  }

  /// Show properties panel for a selected shape (comment + severity)
  void _showShapeProperties(AnnotationShape shape) async {
    String comment = shape.comment;
    Severity sev = shape.severity;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Finding ${shape.findingNumber}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  const Spacer(),
                  Text(shape.typeLabel, style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12)),
                ]),
              ),
              // Severity selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Severity', style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: Severity.values.map((s) => Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => sev = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sev == s ? s.color.withOpacity(0.25) : Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sev == s ? s.color : Colors.grey.shade700, width: sev == s ? 2 : 1),
                            ),
                            child: Column(children: [
                              Icon(s.icon, color: s.color, size: 20),
                              const SizedBox(height: 4),
                              Text(s.label, style: GoogleFonts.poppins(color: sev == s ? s.color : Colors.grey.shade400, fontSize: 11, fontWeight: sev == s ? FontWeight.w700 : FontWeight.normal)),
                            ]),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Comment field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  controller: TextEditingController(text: comment),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Comment / Clinical note',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    hintText: 'e.g. Follow-up in 3 months, compare with prior CT...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                    prefixIcon: Icon(Icons.comment_rounded, color: Colors.grey.shade500),
                  ),
                  onChanged: (v) => comment = v,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade400, side: BorderSide(color: Colors.grey.shade700)),
                    child: const Text('Cancel'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () {
                      _pushHistory();
                      setState(() { shape.comment = comment; shape.severity = sev; });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('Save'),
                  )),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('Clear annotations?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text('All drawings will be removed.', style: GoogleFonts.poppins(color: Colors.grey.shade300)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _pushHistory();
              setState(() { _shapes.clear(); _selectedId = null; _previewShape = null; _findingCounter = 0; });
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Export report as annotated image ─────────────────────────────────────────

  Future<void> _exportReportImage() async {
    if (_bgImage == null) return;
    final visibleShapes = _shapes.where((s) {
      if (s.layer == AnnotationLayer.doctor1 && !_showDoctor1) return false;
      if (s.layer == AnnotationLayer.doctor2 && !_showDoctor2) return false;
      return true;
    }).toList();

    if (visibleShapes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No annotations to export.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      const sidebarW = 360.0;
      final imgW = _bgImage!.width.toDouble();
      final imgH = _bgImage!.height.toDouble();
      final totalW = imgW + sidebarW;
      final totalH = math.max(imgH, 80.0 + visibleShapes.length * 72.0);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // ── Background ──
      canvas.drawRect(Rect.fromLTWH(0, 0, totalW, totalH), Paint()..color = const Color(0xFF0F1929));

      // ── Annotated image (left) — painter draws image + all shapes ──
      _AnnotationPainter(bgImage: _bgImage, shapes: _shapes, selectedId: null).paint(canvas, Size(imgW, imgH));

      // ── Sidebar (right) ──
      final sideX = imgW;
      canvas.drawRect(Rect.fromLTWH(sideX, 0, sidebarW, totalH),
          Paint()..color = const Color(0xFF111827));

      // Header
      final now = DateTime.now();
      _paintText(canvas, 'FINDINGS REPORT', Offset(sideX + 16, 16),
          color: Colors.white, fontSize: 15, bold: true);
      _paintText(canvas, widget.fileName, Offset(sideX + 16, 36),
          color: const Color(0xFF94A3B8), fontSize: 10);
      _paintText(canvas,
          '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
          Offset(sideX + 16, 50), color: const Color(0xFF64748B), fontSize: 10);

      // Divider
      canvas.drawLine(Offset(sideX + 16, 68), Offset(sideX + sidebarW - 16, 68),
          Paint()..color = const Color(0xFF1E3A5F)..strokeWidth = 1);

      // Finding cards
      double y = 78;
      for (final s in visibleShapes) {
        final cardColor = s.severity.color;
        final cardRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(sideX + 12, y, sidebarW - 24, 64),
          const Radius.circular(6),
        );
        canvas.drawRRect(cardRect, Paint()..color = cardColor.withOpacity(0.08)..style = PaintingStyle.fill);
        canvas.drawRRect(cardRect, Paint()..color = cardColor.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 1);

        // Number circle
        canvas.drawCircle(Offset(sideX + 28, y + 18), 12,
            Paint()..color = const Color(0xFF1E3A5F)..style = PaintingStyle.fill);
        _paintText(canvas, '${s.findingNumber}', Offset(sideX + 22, y + 11),
            color: Colors.white, fontSize: 11, bold: true);

        // Type + severity
        _paintText(canvas, s.typeLabel, Offset(sideX + 46, y + 8),
            color: Colors.white, fontSize: 11, bold: true, maxWidth: sidebarW - 70);
        _paintText(canvas, s.severity.label, Offset(sideX + 46, y + 24),
            color: cardColor, fontSize: 10);

        // Timestamp
        final ts = '${s.timestamp.hour.toString().padLeft(2,'0')}:${s.timestamp.minute.toString().padLeft(2,'0')}';
        _paintText(canvas, ts, Offset(sideX + sidebarW - 52, y + 8),
            color: const Color(0xFF64748B), fontSize: 10);

        // Comment
        if (s.comment.isNotEmpty) {
          _paintText(canvas, '"${s.comment}"', Offset(sideX + 46, y + 38),
              color: const Color(0xFFCBD5E1), fontSize: 10, maxWidth: sidebarW - 70);
        }

        y += 72;
      }

      // Footer
      _paintText(canvas, 'Total: ${visibleShapes.length} findings', Offset(sideX + 16, totalH - 24),
          color: const Color(0xFF64748B), fontSize: 10);

      final picture = recorder.endRecording();
      final img = await picture.toImage(totalW.toInt(), totalH.toInt());
      // Use rawRgba for preview (avoids Android PNG decode bug), PNG only for saving
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;

      final bytes = bd!.buffer.asUint8List();
      // Show preview with save options — use RawImage to avoid re-decode on Android
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(children: [
                  const Icon(Icons.image_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text('Report Preview', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: InteractiveViewer(
                  child: RawImage(image: img, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(children: [
                  Expanded(child: _ExportBtn(
                    icon: Icons.image_outlined,
                    label: 'Save PNG',
                    color: Colors.blue,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _saveImage(bytes);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _ExportBtn(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Save PDF',
                    color: Colors.red.shade400,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _savePdf(bytes, visibleShapes);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _ExportBtn(
                    icon: Icons.copy_rounded,
                    label: 'Copy text',
                    color: Colors.teal,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _buildReportText(visibleShapes)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard'), backgroundColor: Colors.teal),
                      );
                    },
                  )),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _buildReportText(List<AnnotationShape> shapes) {
    final now = DateTime.now();
    final buf = StringBuffer();
    buf.writeln('FINDINGS REPORT — ${widget.fileName}');
    buf.writeln('Generated: ${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}');
    buf.writeln('─' * 48);
    for (final g in [Severity.critical, Severity.suspicious, Severity.normal]) {
      final group = shapes.where((s) => s.severity == g).toList();
      if (group.isEmpty) continue;
      buf.writeln('\n${g.label.toUpperCase()} (${group.length})');
      for (final s in group) buf.writeln('  ${s.summaryLine}');
    }
    buf.writeln('\n─' * 48);
    buf.writeln('Total findings: ${shapes.length}');
    if (_pxPerMm != null) buf.writeln('Scale: ${(1 / _pxPerMm! * 10).toStringAsFixed(3)} mm/10px');
    return buf.toString();
  }

  void _paintText(Canvas canvas, String text, Offset pos, {
    Color color = Colors.white,
    double fontSize = 12,
    bool bold = false,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color, fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, pos);
  }

  // ── Save as PNG ───────────────────────────────────────────────────────────────

  Future<void> _saveImage(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/report_$ts.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Findings Report — ${widget.fileName}',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ── Save as PDF ───────────────────────────────────────────────────────────────

  Future<void> _savePdf(Uint8List imageBytes, List<AnnotationShape> shapes) async {
    try {
      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(imageBytes);
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // Severity colour map for PDF
      PdfColor _severityColor(Severity s) {
        switch (s) {
          case Severity.critical:   return const PdfColor.fromInt(0xFFEF4444);
          case Severity.suspicious: return const PdfColor.fromInt(0xFFF59E0B);
          case Severity.normal:     return const PdfColor.fromInt(0xFF22C55E);
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Expanded(child: pw.Text('FINDINGS REPORT',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800))),
                pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ]),
              pw.Text(widget.fileName,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              if (_pxPerMm != null)
                pw.Text('Scale: ${(1 / _pxPerMm! * 10).toStringAsFixed(3)} mm / 10 px',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              pw.Divider(color: PdfColors.blueGrey200),
              pw.SizedBox(height: 4),
            ],
          ),
          build: (_) => [
            // Annotated image
            pw.Center(
              child: pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(maxHeight: 320),
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Findings (${shapes.length})',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 8),
            // One card per finding
            ...shapes.map((s) {
              final col = _severityColor(s.severity);
              final ts2 = '${s.timestamp.hour.toString().padLeft(2, '0')}:${s.timestamp.minute.toString().padLeft(2, '0')}';
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: col, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  color: PdfColor(col.red, col.green, col.blue, 0.06),
                ),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  // Number badge
                  pw.Container(
                    width: 24, height: 24,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                      shape: pw.BoxShape.circle,
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('${s.findingNumber}',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(children: [
                      pw.Expanded(child: pw.Text(s.typeLabel,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Text(s.severity.label,
                          style: pw.TextStyle(fontSize: 10, color: col, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 8),
                      pw.Text(ts2, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                    ]),
                    if (s.comment.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('"${s.comment}"',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ])),
                ]),
              );
            }),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.blueGrey200),
            pw.Text('Total findings: ${shapes.length}  •  Generated by ProDoc',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final ts3 = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/report_$ts3.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Findings Report — ${widget.fileName}',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF failed: $e')));
    }
  }

  // ── Export ───────────────────────────────────────────────────────────────────

  Future<void> _done() async {
    if (_bgImage == null) { Navigator.of(context).pop(null); return; }
    setState(() => _isSaving = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final w = _bgImage!.width.toDouble(), h = _bgImage!.height.toDouble();
      _AnnotationPainter(bgImage: _bgImage, shapes: _shapes, selectedId: null).paint(canvas, Size(w, h));
      final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) Navigator.of(context).pop(bd!.buffer.asUint8List());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildCanvas()),
          _buildToolbar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F1929),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Annotate Image', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(widget.fileName, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400), overflow: TextOverflow.ellipsis),
        ],
      ),
      actions: [
        // Findings count badge
        if (_shapes.isNotEmpty)
          GestureDetector(
            onTap: _showFindingsSummary,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade700),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.format_list_numbered_rounded, size: 14, color: Colors.lightBlueAccent),
                const SizedBox(width: 4),
                Text('${_shapes.length}', style: GoogleFonts.poppins(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),

        // Second opinion layer toggles
        if (_shapes.any((s) => s.layer == AnnotationLayer.doctor2))
          Row(mainAxisSize: MainAxisSize.min, children: [
            _LayerToggle(label: 'Dr1', active: _showDoctor1, color: Colors.blue, onTap: () => setState(() => _showDoctor1 = !_showDoctor1)),
            _LayerToggle(label: 'Dr2', active: _showDoctor2, color: Colors.orange, onTap: () => setState(() => _showDoctor2 = !_showDoctor2)),
          ]),

        IconButton(icon: const Icon(Icons.zoom_out_rounded), onPressed: () {
          setState(() { _zoom = (_zoom - 0.25).clamp(0.5, 5.0); _transformController.value = Matrix4.identity()..scale(_zoom); });
        }),
        IconButton(icon: const Icon(Icons.zoom_in_rounded), onPressed: () {
          setState(() { _zoom = (_zoom + 0.25).clamp(0.5, 5.0); _transformController.value = Matrix4.identity()..scale(_zoom); });
        }),
        IconButton(icon: const Icon(Icons.undo_rounded), onPressed: _undoStack.isNotEmpty ? _undo : null),
        IconButton(icon: const Icon(Icons.redo_rounded), onPressed: _redoStack.isNotEmpty ? _redo : null),
        IconButton(icon: const Icon(Icons.delete_sweep_rounded), onPressed: _shapes.isNotEmpty ? _clearAll : null),
        // Findings summary
        IconButton(
          icon: const Icon(Icons.summarize_rounded),
          tooltip: 'Findings Report',
          onPressed: _shapes.isNotEmpty ? _showFindingsSummary : null,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _isSaving
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : TextButton.icon(
                  onPressed: _done,
                  icon: const Icon(Icons.check_rounded, color: Colors.greenAccent),
                  label: Text('Done', style: GoogleFonts.poppins(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                ),
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    if (_imageLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5, maxScale: 8.0,
          child: Center(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final size = _bgImage != null
                    ? _fitSize(Size(_bgImage!.width.toDouble(), _bgImage!.height.toDouble()), constraints)
                    : Size(constraints.maxWidth, constraints.maxHeight);
                _canvasSize = size;

                return GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _AnnotationPainter(
                      bgImage: _bgImage,
                      bgImage2: _bgImage2,
                      shapes: _shapes,
                      previewShape: _previewShape,
                      selectedId: _selectedId,
                      showDoctor1: _showDoctor1,
                      showDoctor2: _showDoctor2,
                      splitFraction: _isSplitMode ? _splitFraction : 1.0,
                    ),
                    size: size,
                  ),
                );
              },
            ),
          ),
        ),

        // Angle step hint
        if (_tool == AnnotationTool.angle && _angleStep > 0)
          Positioned(
            top: 12, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _angleStep == 1 ? 'Tap to set first arm of angle' : 'Tap to complete angle',
                  style: GoogleFonts.poppins(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),

        // Floating delete / properties button when selected
        if (_selectedId != null)
          Positioned(
            top: 12, right: 12,
            child: Column(
              children: [
                _FloatingActionBtn(
                  icon: Icons.edit_note_rounded,
                  label: 'Properties',
                  color: Colors.blue.shade700,
                  onTap: () {
                    final s = _shapes.firstWhere((s) => s.id == _selectedId);
                    _showShapeProperties(s);
                  },
                ),
                const SizedBox(height: 8),
                _FloatingActionBtn(
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  color: Colors.red.shade700,
                  onTap: () {
                    _pushHistory();
                    setState(() { _shapes.removeWhere((s) => s.id == _selectedId); _selectedId = null; _isDragging = false; _dragShapeSnapshot = null; _draggingEndpoint = null; });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Size _fitSize(Size img, BoxConstraints c) {
    final s = math.min(c.maxWidth / img.width, c.maxHeight / img.height);
    return Size(img.width * s, img.height * s);
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF0F1929),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
              tabs: const [
                Tab(text: 'Draw'),
                Tab(text: 'Medical'),
                Tab(text: 'Style'),
              ],
            ),
            SizedBox(
              height: 72,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Draw tab ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        _ToolBtn(icon: Icons.near_me_rounded,         label: 'Select',  tool: AnnotationTool.select,    active: _tool, onTap: () => _setTool(AnnotationTool.select)),
                        _ToolBtn(icon: Icons.edit_rounded,            label: 'Pen',     tool: AnnotationTool.freeStyle, active: _tool, onTap: () => _setTool(AnnotationTool.freeStyle)),
                        _ToolBtn(icon: Icons.auto_fix_normal_rounded, label: 'Eraser',  tool: AnnotationTool.eraser,    active: _tool, onTap: () => _setTool(AnnotationTool.eraser)),
                        _ToolBtn(icon: Icons.text_fields_rounded,     label: 'Text',    tool: AnnotationTool.text,      active: _tool, onTap: () => _setTool(AnnotationTool.text)),
                        _ToolBtn(icon: Icons.remove_rounded,          label: 'Line',    tool: AnnotationTool.line,      active: _tool, onTap: () => _setTool(AnnotationTool.line)),
                        _ToolBtn(icon: Icons.crop_square_rounded,     label: 'Rect',    tool: AnnotationTool.rect,      active: _tool, onTap: () => _setTool(AnnotationTool.rect)),
                        _ToolBtn(icon: Icons.circle_outlined,         label: 'Circle',  tool: AnnotationTool.circle,    active: _tool, onTap: () => _setTool(AnnotationTool.circle)),
                        _ToolBtn(icon: Icons.arrow_forward_rounded,   label: 'Arrow',   tool: AnnotationTool.arrow,     active: _tool, onTap: () => _setTool(AnnotationTool.arrow)),
                      ],
                    ),
                  ),

                  // ── Medical tab ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        _ToolBtn(icon: Icons.highlight_rounded,   label: 'ROI',     tool: AnnotationTool.roi,     active: _tool, onTap: () => _setTool(AnnotationTool.roi),     accentColor: Colors.teal),
                        _ToolBtn(icon: Icons.straighten_rounded,  label: 'Measure', tool: AnnotationTool.measure, active: _tool, onTap: () => _setTool(AnnotationTool.measure), accentColor: Colors.teal),
                        _ToolBtn(icon: Icons.architecture_rounded,label: 'Angle',   tool: AnnotationTool.angle,   active: _tool, onTap: () => _setTool(AnnotationTool.angle),   accentColor: Colors.teal),
                        _ToolBtn(icon: Icons.label_rounded,       label: 'Stamp',   tool: AnnotationTool.stamp,   active: _tool, onTap: () => _setTool(AnnotationTool.stamp),   accentColor: Colors.amber),
                        // Specialty picker
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade700)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSpecialty,
                              dropdownColor: Colors.grey.shade900,
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                              icon: Icon(Icons.expand_more_rounded, color: Colors.grey.shade400, size: 16),
                              items: kStampPresets.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                              onChanged: (v) => setState(() => _selectedSpecialty = v!),
                            ),
                          ),
                        ),
                        // Calibration indicator
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _pxPerMm != null ? _resetCalibration : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _pxPerMm != null ? Colors.teal.withOpacity(0.2) : Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _pxPerMm != null ? Colors.tealAccent : Colors.grey.shade700),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.linear_scale_rounded, size: 13,
                                  color: _pxPerMm != null ? Colors.tealAccent : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                _pxPerMm != null
                                    ? '${(1 / _pxPerMm! * 10).toStringAsFixed(2)} mm/10px'
                                    : 'No scale',
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: _pxPerMm != null ? Colors.tealAccent : Colors.grey.shade500,
                                    fontWeight: _pxPerMm != null ? FontWeight.w700 : FontWeight.normal),
                              ),
                              if (_pxPerMm != null) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.close_rounded, size: 11, color: Colors.tealAccent.withOpacity(0.7)),
                              ],
                            ]),
                          ),
                        ),
                        // Layer selector
                        const SizedBox(width: 8),
                        _LayerBtn(label: 'Dr1', layer: AnnotationLayer.doctor1, active: _activeLayer, color: Colors.blue, onTap: () => setState(() => _activeLayer = AnnotationLayer.doctor1)),
                        const SizedBox(width: 4),
                        _LayerBtn(label: 'Dr2', layer: AnnotationLayer.doctor2, active: _activeLayer, color: Colors.orange, onTap: () => setState(() => _activeLayer = AnnotationLayer.doctor2)),
                      ],
                    ),
                  ),

                  // ── Style tab ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Severity
                        ...Severity.values.map((s) => GestureDetector(
                          onTap: () => setState(() => _severity = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _severity == s ? s.color.withOpacity(0.2) : Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _severity == s ? s.color : Colors.grey.shade700),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(s.icon, color: s.color, size: 14),
                              const SizedBox(width: 4),
                              Text(s.label, style: GoogleFonts.poppins(color: _severity == s ? s.color : Colors.grey.shade400, fontSize: 10, fontWeight: _severity == s ? FontWeight.w700 : FontWeight.normal)),
                            ]),
                          ),
                        )),
                        Container(width: 1, height: 36, color: Colors.grey.shade700, margin: const EdgeInsets.symmetric(horizontal: 8)),
                        // Colors
                        ..._colors.map((c) => GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            width: _color == c ? 28 : 22,
                            height: _color == c ? 28 : 22,
                            decoration: BoxDecoration(
                              color: c, shape: BoxShape.circle,
                              border: Border.all(color: _color == c ? Colors.white : Colors.grey.shade600, width: _color == c ? 2.5 : 1),
                            ),
                          ),
                        )),
                        Container(width: 1, height: 36, color: Colors.grey.shade700, margin: const EdgeInsets.symmetric(horizontal: 8)),
                        // Stroke width
                        Icon(Icons.line_weight_rounded, color: Colors.grey.shade400, size: 16),
                        SizedBox(
                          width: 90,
                          child: Slider(value: _strokeWidth, min: 1, max: 16, activeColor: _color,
                              onChanged: (v) => setState(() => _strokeWidth = v)),
                        ),
                        Text('${_strokeWidth.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setTool(AnnotationTool tool) {
    setState(() {
      _tool = tool;
      _previewShape = null;
      _isDrawing = false;
      _isDragging = false;
      _draggingEndpoint = null;
      _dragShapeSnapshot = null;
      _angleStep = 0;
      _angleVertex = null;
      _angleP1 = null;
      if (tool != AnnotationTool.select) _selectedId = null;
    });
  }

  static const List<Color> _colors = [
    Colors.red, Colors.orange, Colors.yellow, Colors.green,
    Colors.blue, Colors.purple, Colors.white, Colors.black,
    Color(0xFF00BCD4), Color(0xFFFF4081),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final AnnotationTool tool;
  final AnnotationTool active;
  final VoidCallback onTap;
  final Color? accentColor;

  const _ToolBtn({required this.icon, required this.label, required this.tool, required this.active, required this.onTap, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isActive = active == tool;
    final accent = accentColor ?? Colors.blue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? accent.withOpacity(0.25) : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? accent : Colors.grey.shade700),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isActive ? accent : Colors.grey.shade400),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.poppins(fontSize: 9, color: isActive ? accent : Colors.grey.shade400, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _LayerBtn extends StatelessWidget {
  final String label;
  final AnnotationLayer layer;
  final AnnotationLayer active;
  final Color color;
  final VoidCallback onTap;

  const _LayerBtn({required this.label, required this.layer, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = active == layer;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.25) : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? color : Colors.grey.shade700),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: isActive ? color : Colors.grey.shade400, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _LayerToggle({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color : Colors.grey.shade700),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: active ? color : Colors.grey.shade500, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

class _FloatingActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FloatingActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))]),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Finding card in the report sheet ─────────────────────────────────────────

class _FindingCard extends StatelessWidget {
  final AnnotationShape shape;
  const _FindingCard({required this.shape});

  @override
  Widget build(BuildContext context) {
    final ts = '${shape.timestamp.hour.toString().padLeft(2, '0')}:${shape.timestamp.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shape.severity.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: shape.severity.color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Finding number circle
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0xFF1E3A5F), shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade700)),
            alignment: Alignment.center,
            child: Text('${shape.findingNumber}',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(shape.typeLabel,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  Icon(shape.severity.icon, color: shape.severity.color, size: 16),
                  const SizedBox(width: 4),
                  Text(shape.severity.label, style: GoogleFonts.poppins(color: shape.severity.color, fontSize: 11)),
                ]),
                const SizedBox(height: 2),
                Text(ts, style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 10)),
                if (shape.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.comment_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(child: Text(shape.comment,
                        style: GoogleFonts.poppins(color: Colors.grey.shade300, fontSize: 11, fontStyle: FontStyle.italic))),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Export button widget ──────────────────────────────────────────────────────

class _ExportBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}