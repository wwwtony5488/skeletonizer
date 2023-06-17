import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:skeletonizer/src/painting/paintable_element.dart';
import 'package:skeletonizer/src/utils.dart';

class TextElement extends PaintableElement {
  final List<LineMetrics> lines;
  final double fontSize;
  final Size textSize;
  final BorderRadius? borderRadius;
  final bool justifyMultiLines;
  final TextDirection textDirection;
  final TextAlign textAlign;

  TextElement({
    required super.offset,
    required this.lines,
    required this.fontSize,
    required this.textSize,
    required this.textDirection,
    required this.textAlign,
    this.borderRadius,
    this.justifyMultiLines = true,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TextElement &&
            runtimeType == other.runtimeType &&
            const ListEquality().equals(lines, other.lines) &&
            fontSize == other.fontSize &&
            textSize == other.textSize &&
            textDirection == other.textDirection &&
            textAlign == other.textAlign &&
            offset == other.offset &&
            borderRadius == other.borderRadius;
  }

  @override
  int get hashCode =>
      const ListEquality().hash(lines) ^
      fontSize.hashCode ^
      textSize.hashCode ^
      borderRadius.hashCode ^
      offset.hashCode ^
      textAlign.hashCode ^
      textDirection.hashCode;

  @override
  Rect get rect => offset & textSize;

  @override
  void paint(PaintingContext context, Offset offset, Paint shaderPaint) {
    final globalOffset = this.offset + offset;
    var yOffset = globalOffset.dy;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final shouldJustify =
          justifyMultiLines && textAlign != TextAlign.center && (lines.length > 1 && i < (lines.length - 1));
      final width = shouldJustify ? textSize.width : line.width;
      final rect = Rect.fromLTWH(
        shouldJustify ? globalOffset.dx : line.left + globalOffset.dx,
        yOffset + line.descent,
        width,
        fontSize,
      );
      if (borderRadius != null) {
        context.canvas.drawRRect(rect.toRRect(borderRadius!), shaderPaint);
      } else {
        context.canvas.drawRect(rect, shaderPaint);
      }
      yOffset += line.height;
    }
  }

  @override
  String toString() {
    return 'TextElement{lines: $lines, fontSize: $fontSize, textSize: $textSize, borderRadius: $borderRadius, justifyMultiLines: $justifyMultiLines, textDirection: $textDirection, textAlign: $textAlign}';
  }
}