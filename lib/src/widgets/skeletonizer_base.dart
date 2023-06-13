import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:skeleton_builder/skeleton_builder.dart';
import 'package:collection/collection.dart';
import 'package:skeleton_builder/src/helper_utils.dart';
import 'package:skeleton_builder/src/painting/paintable_element.dart';
import 'dart:math' as math;

const double _kQuarterTurnsInRadians = math.pi / 2.0;

class SkeletonizerBase extends SingleChildRenderObjectWidget {
  const SkeletonizerBase({
    super.key,
    required super.child,
    required this.enabled,
    required this.effect,
    required this.animationValue,
    required this.brightness,
    required this.textDirection,
  });

  final PaintingEffect effect;
  final bool enabled;
  final double animationValue;
  final Brightness brightness;
  final TextDirection textDirection;

  @override
  RenderSkeletonizer createRenderObject(BuildContext context) {
    return RenderSkeletonizer(
      enabled: enabled,
      paintingEffect: effect,
      animationValue: animationValue,
      brightness: brightness,
      textDirection: textDirection,
    );
  }



  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSkeletonizer renderObject,
  ) {
    renderObject
      ..enabled = enabled
      ..animationValue = animationValue
      ..paintingEffect = effect
      ..brightness = brightness
      ..textDirection = textDirection;
  }
}

class RenderSkeletonizer extends RenderProxyBox {
  RenderSkeletonizer({
    required bool enabled,
    required TextDirection textDirection,
    required double animationValue,
    required Brightness brightness,
    RenderBox? child,
    required PaintingEffect paintingEffect,
  })  : _animationValue = animationValue,
        _enabled = enabled,
        _paintingEffect = paintingEffect,
        _textDirection = textDirection,
        _brightness = brightness,
        super(child);

  TextDirection _textDirection;

  TextDirection get textDirection => _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection != value) {
      _textDirection = value;
      _needsSkeletonizing = true;
      markNeedsPaint();
    }
  }


  Brightness _brightness;

  Brightness get brightness => _brightness;

  set brightness(Brightness value) {
    if (_brightness != value) {
      _brightness = value;
      _needsSkeletonizing = true;
      markNeedsPaint();
    }
  }

  bool _enabled;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled != value) {
      _enabled = value;
      _needsSkeletonizing = true;
    }
  }

  PaintingEffect _paintingEffect;

  set paintingEffect(PaintingEffect value) {
    if (_paintingEffect != value) {
      _paintingEffect = value;
      markNeedsPaint();
    }
  }

  double _animationValue = 0;

  set animationValue(double value) {
    if (_animationValue != value) {
      _animationValue = value;
      markNeedsPaint();
    }
  }


  void _skeletonize() {
    _needsSkeletonizing = false;
    _paintableElements.clear();
    _skeletonizeRecursively(this, _paintableElements, Offset.zero);
  }

  final _paintableElements = <PaintableElement>[];

  void _skeletonizeRecursively(RenderObject node, List<PaintableElement> elements, Offset offset) {
    // avoid skeletonizing renderers outside of screen bounds
    //
    // this may need to shifting by parent offset
    if (!paintBounds.contains(offset)) {
      return;
    }

    node.visitChildren((child) {
      var childOffset = offset;
      if (child.hasParentData) {
        final transform = Matrix4.identity();
        if (node is! RenderTransform && node is! RenderRotatedBox) {
          node.applyPaintTransform(child, transform);
          childOffset = MatrixUtils.transformPoint(transform, offset);
        }
      }
      if (child is RenderSkeletonAnnotation) {
        if (child.annotation is IgnoreDescendants) {
          return;
        } else if (child.annotation is ShadeOriginal) {
          return elements.add(
            ShadedElement(
              offset: childOffset,
              renderObject: child.child!,
              canvasSize: size,
            ),
          );
        } else if (child.annotation is KeepOriginal) {
          return elements.add(
            OriginalElement(
              offset: childOffset,
              renderObject: child.child!,
            ),
          );
        } else if (child.annotation is TreatAsLeaf) {
          final descendent = _getDescendents(child.child!, childOffset).firstOrNull;
          if (descendent != null) {
            if (descendent is AncestorElement) {
              descendent.descendents.clear();
            }
            elements.add(descendent);
          }
          return;
        }
      } else if (child is RenderBox) {
        if (child is RenderClipRRect) {
          final descendents = _getDescendents(child, childOffset);
          if (child.clipBehavior == Clip.none) {
            elements.addAll(descendents);
          } else if (descendents.isNotEmpty) {
            final RRect clipRect;
            if (child.clipper != null) {
              clipRect = child.clipper!.getClip(child.size);
            } else {
              final borderRadius = child.borderRadius.resolve(textDirection);
              clipRect = (childOffset & child.size).toRRect(borderRadius);
            }
            elements.add(
              RRectClipElement(
                clip: clipRect,
                offset: childOffset,
                descendents: descendents,
              ),
            );
          }
          return;
        } else if (child is RenderClipPath) {
          final descendents = _getDescendents(child, childOffset);
          final clipper = child.clipper;
          if (child.clipBehavior == Clip.none) {
            elements.addAll(descendents);
          } else if (clipper != null && descendents.isNotEmpty) {
            elements.add(
              PathClipElement(
                offset: childOffset,
                clip: clipper.getClip(child.size),
                descendents: _getDescendents(child, childOffset),
              ),
            );
            return;
          }
        } else if (child is RenderClipOval) {
          final descendents = _getDescendents(child, childOffset);
          if (child.clipBehavior == Clip.none) {
            elements.addAll(descendents);
          } else if (descendents.isNotEmpty) {
            final rect = child.clipper?.getClip(child.size) ?? child.paintBounds;
            elements.add(
              PathClipElement(
                offset: childOffset,
                clip: Path()..addOval(rect),
                descendents: descendents,
              ),
            );
          }
          return;
        } else if (child is RenderClipRect) {
          final descendents = _getDescendents(child, childOffset);
          if (child.clipBehavior == Clip.none) {
            elements.addAll(descendents);
          } else if (descendents.isNotEmpty) {
            elements.add(
              RectClipElement(
                offset: childOffset,
                clip: child.clipper?.getClip(child.size) ?? child.paintBounds,
                descendents: descendents,
              ),
            );
          }
          return;
        } else if (child is RenderTransform) {
          final descendents = _getDescendents(child, childOffset);
          if (descendents.isNotEmpty) {
            elements.add(
              TransformElement(
                matrix4: debugValueOfType<Matrix4>(child)!.clone(),
                size: child.size,
                textDirection: textDirection,
                origin: child.origin,
                alignment: child.alignment,
                descendents: descendents,
                offset: offset,
              ),
            );
          }
          return;
        } else if (child is RenderImage) {
          elements.add(BoneElement(rect: childOffset & child.size));
        } else if (child is RenderParagraph) {
          elements.add(_buildTextBone(child, childOffset));
        } else if (child is RenderPhysicalModel) {
          elements.add(_buildPhysicalModel(child, childOffset));
        } else if (child is RenderPhysicalShape) {
          elements.add(_buildPhysicalShape(child, childOffset));
        } else if (child is RenderDecoratedBox) {
          elements.add(_buildDecoratedBox(child, childOffset));
        } else if (child is RenderCustomPaint) {
          // print('Custom Painter');
          // elements.add(
          //   ShadedElement(
          //     offset: childOffset,
          //     canvasSize: size,
          //     renderObject: child,
          //   ),
          // );
          // return;
        } else if (child.widget is ColoredBox) {
          elements.add(
            ContainerElement(
              rect: childOffset & child.size,
              color: (child.widget as ColoredBox).color,
              descendents: _getDescendents(child, childOffset),
            ),
          );
          return;
        } else if (child is RenderRotatedBox) {
          final element = _buildRotatedBox(child, childOffset);
          if (element != null) {
            elements.add(element);
          }
          return;
        } else {}
      }

      _skeletonizeRecursively(child, elements, childOffset);
    });
  }

  List<PaintableElement> _getDescendents(RenderObject child, Offset childOffset) {
    final descendents = <PaintableElement>[];
    _skeletonizeRecursively(child, descendents, childOffset);
    return descendents;
  }

  TextBoneElement _buildTextBone(RenderParagraph node, Offset offset) {
    final painter = TextPainter(
      text: node.text,
      textAlign: node.textAlign,
      textDirection: node.textDirection,
      textScaleFactor: node.textScaleFactor,
      maxLines: node.maxLines,
    )..layout(maxWidth: node.constraints.maxWidth);
    final fontSize = (node.text.style?.fontSize ?? 14) * node.textScaleFactor;
    return TextBoneElement(
      fontSize: fontSize,
      lines: painter.computeLineMetrics(),
      offset: offset,
    );
  }

  ContainerElement _buildDecoratedBox(RenderDecoratedBox node, Offset offset) {
    final boxDecoration = node.decoration is BoxDecoration ? (node.decoration as BoxDecoration) : const BoxDecoration();
    return ContainerElement(
      rect: offset & node.size,
      border: boxDecoration.border,
      borderRadius: boxDecoration.borderRadius?.resolve(textDirection),
      descendents: _getDescendents(node, offset),
      color: boxDecoration.color,
      boxShape: boxDecoration.shape,
      boxShadow: boxDecoration.boxShadow,
    );
  }

  TransformElement? _buildRotatedBox(RenderRotatedBox child, Offset childOffset) {
    final descendents = _getDescendents(child, childOffset);
    if (descendents.isNotEmpty) {
      final transChild = child.child!;
      final transform = Matrix4.identity()
        ..translate(child.size.width / 2.0, child.size.height / 2.0)
        ..rotateZ(_kQuarterTurnsInRadians * (child.quarterTurns % 4))
        ..translate(-transChild.size.width / 2.0, -transChild.size.height / 2.0);
      return TransformElement(
        matrix4: transform,
        descendents: descendents,
        textDirection: textDirection,
        size: child.size,
        offset: childOffset,
      );
    }
    return null;
  }

  Map<String, Object?> debugPropertiesMap(Diagnosticable node) {
    return Map.fromEntries(
      debugProperties(node).where((e) => e.name != null).map(
            (e) => MapEntry(e.name!, e.value),
          ),
    );
  }

  List<DiagnosticsNode> debugProperties(Diagnosticable node) {
    final builder = DiagnosticPropertiesBuilder();
    node.debugFillProperties(builder);
    return builder.properties;
  }

  T? debugValueOfType<T>(RenderObject node) {
    return debugProperties(node).firstWhereOrNull((e) => e.value is T)?.value as T?;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return !enabled && super.hitTest(result, position: position);
  }

  bool _needsSkeletonizing = true;

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    super.layout(constraints, parentUsesSize: parentUsesSize);
    _needsSkeletonizing = true;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      return super.paint(context, offset);
    }
    if (_needsSkeletonizing) _skeletonize();
    final paint = _paintingEffect.createPaint(_animationValue, offset & size);
    for (final element in _paintableElements) {
      element.paint(context, offset, paint);
    }
  }

  ContainerElement _buildPhysicalShape(RenderPhysicalShape node, Offset offset) {
    final isChip = node.isInside<RawChip>();
    if (isChip) {
      node.findChild(print);
    }
    final isButton = node.findParentWithName('_RenderInputPadding') != null;
    final shape = (node.clipper as ShapeBorderClipper).shape;
    BorderRadiusGeometry? borderRadius;
    if (shape is RoundedRectangleBorder) {
      borderRadius = shape.borderRadius;
    } else if (shape is StadiumBorder) {
      borderRadius = BorderRadius.circular(node.size.height);
    }

    return ContainerElement(
      rect: offset & node.size,
      elevation: node.elevation,
      descendents: isButton ? const [] : _getDescendents(node, offset),
      color: node.color,
      boxShape: shape is CircleBorder ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: borderRadius?.resolve(textDirection),
    );
  }

  ContainerElement _buildPhysicalModel(RenderPhysicalModel node, Offset offset) {
    final shape = node.clipper == null ? null : (node.clipper as ShapeBorderClipper).shape;
    BorderRadiusGeometry? borderRadius;
    if (shape is RoundedRectangleBorder) {
      borderRadius = shape.borderRadius;
    } else if (shape is StadiumBorder) {
      borderRadius = BorderRadius.circular(node.size.height);
    }
    return ContainerElement(
      rect: offset & node.size,
      elevation: node.elevation,
      descendents: _getDescendents(node, offset),
      color: node.color,
      boxShape: shape is CircleBorder ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: borderRadius?.resolve(textDirection),
    );
  }

// @override
// void debugFillProperties(DiagnosticPropertiesBuilder properties) {
//   super.debugFillProperties(properties);
//   properties.add(DiagnosticsProperty<LinearGradient>('_shimmer', _shaderPaint));
// }
}