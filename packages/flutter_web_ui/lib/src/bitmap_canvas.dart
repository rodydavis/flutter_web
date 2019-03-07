// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'canvas.dart';
import 'compositing.dart' show SceneBuilder;
import 'engine_canvas.dart';
import 'geometry.dart';
import 'html_image_codec.dart';
import 'painting.dart';
import 'recording_canvas.dart';
import 'shadow.dart';
import 'text/ruler.dart';
import 'text.dart';
import 'util.dart';

/// A raw HTML canvas that is directly written to.
class BitmapCanvas implements EngineCanvas {
  /// The rectangle positioned relative to the parent layer's coordinate
  /// system's origin, within which this canvas paints.
  ///
  /// Painting outside these bounds will result in cropping.
  Rect bounds;

  final html.Element rootElement = new html.Element.tag('flt-canvas');
  html.CanvasElement _canvas;
  html.CanvasRenderingContext2D _ctx;

  /// The size of the paint [bounds].
  Size get size => bounds.size;

  /// The last paragraph style is cached to optimize the case where the style
  /// hasn't changed.
  ParagraphGeometricStyle _cachedLastStyle;

  final _paragraphs = new Set<html.Element>();

  int _width;
  int _height;

  int _saveCount = 0;

  BitmapCanvas(this.bounds);

  void apply(PaintCommand command) {
    command.apply(this);
  }

  /// Prepare to reuse this canvas by clearing it's current contents.
  void clear() {
    // Flutter emits paint operations positioned relative to the parent layer's
    // coordinate system. However, canvas' coordinate system's origin is always
    // in the top-left corner of the canvas. We therefore need to inject an
    // initial translation so the paint operations are positioned as expected.
    if (bounds.left != 0.0 || bounds.top != 0.0) {
      rootElement.style.transform =
          'translate(${bounds.left.toInt()}px, ${bounds.top.toInt()}px)';
    } else {
      rootElement.style.transform = null;
    }
    _paragraphs.forEach((p) => p.remove());
    _paragraphs.clear();
    _cachedLastStyle = null;
    // Restore to the state where we have only applied the scaling.
    if (_ctx != null) {
      _ctx.restore();
      _ctx.clearRect(0, 0, _width, _height);
      _ctx.font = '';
      _initializeViewport();
    }
    if (_canvas != null) {
      _canvas.style.transformOrigin = '';
      _canvas.style.transform = '';
    }
  }

  void _initializeCanvas() {
    rootElement.style.position = 'absolute';
    double boundsWidth = size.width;
    double boundsHeight = size.height;
    _width = (boundsWidth * html.window.devicePixelRatio).toInt();
    _height = (boundsHeight * html.window.devicePixelRatio).toInt();
    _canvas = new html.CanvasElement(
      width: _width,
      height: _height,
    );
    _canvas.style
      ..position = 'absolute'
      ..width = '${boundsWidth.toInt()}px'
      ..height = '${boundsHeight.toInt()}px';
    _ctx = _canvas.context2D;
    rootElement.append(_canvas);
    _initializeViewport();
  }

  /// Configures the canvas such that its coordinate system follows the scene's
  /// coordinate system, and the pixel ratio is applied such that CSS pixels are
  /// translated to bitmap pixels.
  void _initializeViewport() {
    // Save the canvas state with top-level transforms so we can undo
    // any clips later when we reuse the canvas.
    _ctx.save();

    // We always start with identity transform because the surrounding transform
    // is applied on the DOM elements.
    _ctx.setTransform(1, 0, 0, 1, 0, 0);

    // This scale makes sure that 1 CSS pixel is translated to the correct
    // number of bitmap pixels.
    _ctx.scale(html.window.devicePixelRatio, html.window.devicePixelRatio);

    // This compensates for the translate on the `rootElement`.
    _ctx.translate(-bounds.left, -bounds.top);
  }

  html.CanvasElement get canvas {
    if (_canvas == null) _initializeCanvas();
    return _canvas;
  }

  html.CanvasRenderingContext2D get ctx {
    if (_canvas == null) _initializeCanvas();
    return _ctx;
  }

  /// Sets the global paint styles to correspond to [paint].
  void _applyPaint(Paint paint) {
    ctx.globalCompositeOperation =
        _stringForBlendMode(paint.blendMode) ?? 'source-over';
    ctx.lineWidth = paint.strokeWidth ?? 1.0;
    ctx.lineCap = _stringForStrokeCap(paint.strokeCap) ?? 'butt';
    if (paint.shader != null) {
      var paintStyle = paint.shader.createPaintStyle(ctx);
      ctx.fillStyle = paintStyle;
      ctx.strokeStyle = paintStyle;
    } else if (paint.color != null) {
      var colorString = paint.color.toCssString();
      ctx.fillStyle = colorString;
      ctx.strokeStyle = colorString;
    }
    if (paint.maskFilter != null) {
      ctx.filter = 'blur(${paint.maskFilter.webOnlySigma}px)';
    }
  }

  void _strokeOrFill(Paint paint, {bool resetPaint = true}) {
    switch (paint.style) {
      case PaintingStyle.stroke:
        ctx.stroke();
        break;
      case PaintingStyle.strokeAndFill:
        ctx.stroke();
        ctx.fill();
        break;
      case PaintingStyle.fill:
      default:
        ctx.fill();
        break;
    }
    if (resetPaint) {
      _resetPaint();
    }
  }

  /// Resets the paint styles that were set due to a previous paint command.
  ///
  /// For example, if a previous paint commands has a blur filter, we need to
  /// undo that filter here.
  ///
  /// This needs to be called after [_applyPaint].
  void _resetPaint() {
    ctx.filter = 'none';
    ctx.fillStyle = null;
    ctx.strokeStyle = null;
  }

  int save() {
    ctx.save();
    return _saveCount++;
  }

  void saveLayer(Rect bounds, _) {
    save();
  }

  void restore() {
    ctx.restore();
    _saveCount--;
    _cachedLastStyle = null;
  }

  void restoreToCount(int count) {
    assert(_saveCount >= count);
    int restores = _saveCount - count;
    for (int i = 0; i < restores; i++) {
      ctx.restore();
    }
    _saveCount = count;
  }

  void translate(double dx, double dy) {
    ctx.translate(dx, dy);
  }

  void scale(double sx, double sy) {
    ctx.scale(sx, sy);
  }

  void rotate(double radians) {
    ctx.rotate(radians);
  }

  void skew(double sx, double sy) {
    ctx.transform(0, sx, sy, 0, 0, 0);
  }

  Matrix4 get currentTransform {
    var domTransform = _ctx.currentTransform;
    var matrix = Matrix4.identity();
    matrix[0] = domTransform.a;
    matrix[1] = domTransform.b;
    matrix[4] = domTransform.c;
    matrix[5] = domTransform.d;
    matrix[12] = domTransform.e;
    matrix[13] = domTransform.f;
    return matrix;
  }

  void transformMatrix(Matrix4 matrix) {
    _ctx.transform(
      matrix[0],
      matrix[1],
      matrix[4],
      matrix[5],
      matrix[12],
      matrix[13],
    );
  }

  void transform(Float64List matrix4) {
    if (SceneBuilder.webOnlyUseLayerSceneBuilder) {
      _ctx.transform(
        matrix4[0],
        matrix4[1],
        matrix4[4],
        matrix4[5],
        matrix4[12],
        matrix4[13],
      );
    } else {
      canvas.style.transformOrigin = '0 0 0';
      if (matrix4.elementAt(0) == 0 &&
          matrix4.elementAt(1) == 0 &&
          matrix4.elementAt(2) == 0 &&
          matrix4.elementAt(3) == 0 &&
          matrix4.elementAt(4) == 0 &&
          matrix4.elementAt(5) == 0 &&
          matrix4.elementAt(6) == 0 &&
          matrix4.elementAt(7) == 0 &&
          matrix4.elementAt(8) == 0 &&
          matrix4.elementAt(9) == 0 &&
          matrix4.elementAt(10) == 1 &&
          matrix4.elementAt(11) == 0 &&
          matrix4.elementAt(15) == 1) {
        var tx = matrix4.elementAt(12);
        var ty = matrix4.elementAt(13);
        canvas.style.transform = 'translate($tx, $ty)';
      } else {
        // TODO(flutter_web): detect pure scale+translate to replace hack below.
        canvas.style.transform = float64ListToCssTransform(matrix4);
      }
    }
  }

  void clipRect(Rect rect) {
    ctx.beginPath();
    ctx.rect(rect.left, rect.top, rect.width, rect.height);
    ctx.clip();
  }

  void clipRRect(RRect rrect) {
    var path = new Path()..addRRect(rrect);
    _runPath(path);
    ctx.clip();
  }

  void clipPath(Path path) {
    _runPath(path);
    ctx.clip();
  }

  void drawColor(Color color, BlendMode blendMode) {
    ctx.globalCompositeOperation = _stringForBlendMode(blendMode);
    ctx.fillRect(0, 0, size.width, size.height);
  }

  void drawLine(Offset p1, Offset p2, Paint paint) {
    _applyPaint(paint);
    ctx.beginPath();
    ctx.moveTo(p1.dx, p1.dy);
    ctx.lineTo(p2.dx, p2.dy);
    ctx.stroke();
    _resetPaint();
  }

  void drawPaint(Paint paint) {
    _applyPaint(paint);
    ctx.beginPath();
    ctx.fillRect(0, 0, size.width, size.height);
    _resetPaint();
  }

  void drawRect(Rect rect, Paint paint) {
    _applyPaint(paint);
    ctx.beginPath();
    ctx.rect(rect.left, rect.top, rect.width, rect.height);
    _strokeOrFill(paint);
  }

  void drawRRect(RRect rrect, Paint paint) {
    _applyPaint(paint);
    _drawRRectPath(rrect);
    _strokeOrFill(paint);
  }

  void _drawRRectPath(RRect rrect, {bool startNewPath = true}) {
    // TODO(mdebbar): there's a bug in this code, it doesn't correctly handle
    //                the case when the radius is greater than the width of the
    //                rect. When we fix that in houdini_painter.js, we need to
    //                fix it here too.
    // To draw the rounded rectangle, perform the following 8 steps:
    //   1. Flip left,right top,bottom since web doesn't support flipped
    //      coordinates with negative radii.
    //   2. draw the line for the top
    //   3. draw the arc for the top-right corner
    //   4. draw the line for the right side
    //   5. draw the arc for the bottom-right corner
    //   6. draw the line for the bottom of the rectangle
    //   7. draw the arc for the bottom-left corner
    //   8. draw the line for the left side
    //   9. draw the arc for the top-left corner
    //
    // After drawing, the current point will be the left side of the top of the
    // rounded rectangle (after the corner).
    // TODO(het): Confirm that this is the end point in Flutter for RRect

    var left = rrect.left;
    var right = rrect.right;
    var top = rrect.top;
    var bottom = rrect.bottom;
    if (left > right) {
      left = right;
      right = rrect.left;
    }
    if (top > bottom) {
      top = bottom;
      bottom = rrect.top;
    }
    var trRadiusX = rrect.trRadiusX.abs();
    var tlRadiusX = rrect.tlRadiusX.abs();
    var trRadiusY = rrect.trRadiusY.abs();
    var tlRadiusY = rrect.tlRadiusY.abs();
    var blRadiusX = rrect.blRadiusX.abs();
    var brRadiusX = rrect.brRadiusX.abs();
    var blRadiusY = rrect.blRadiusY.abs();
    var brRadiusY = rrect.brRadiusY.abs();

    ctx.moveTo(left + trRadiusX, top);

    if (startNewPath) {
      ctx.beginPath();
    }

    // Top side and top-right corner
    ctx.lineTo(right - trRadiusX, top);
    ctx.ellipse(
      right - trRadiusX,
      top + trRadiusY,
      trRadiusX,
      trRadiusY,
      0,
      1.5 * math.pi,
      2.0 * math.pi,
      false,
    );

    // Right side and bottom-right corner
    ctx.lineTo(right, bottom - brRadiusY);
    ctx.ellipse(
      right - brRadiusX,
      bottom - brRadiusY,
      brRadiusX,
      brRadiusY,
      0,
      0,
      0.5 * math.pi,
      false,
    );

    // Bottom side and bottom-left corner
    ctx.lineTo(left + blRadiusX, bottom);
    ctx.ellipse(
      left + blRadiusX,
      bottom - blRadiusY,
      blRadiusX,
      blRadiusY,
      0,
      0.5 * math.pi,
      math.pi,
      false,
    );

    // Left side and top-left corner
    ctx.lineTo(left, top + tlRadiusY);
    ctx.ellipse(
      left + tlRadiusX,
      top + tlRadiusY,
      tlRadiusX,
      tlRadiusY,
      0,
      math.pi,
      1.5 * math.pi,
      false,
    );
  }

  void _drawRRectPathReverse(RRect rrect, {bool startNewPath = true}) {
    var left = rrect.left;
    var right = rrect.right;
    var top = rrect.top;
    var bottom = rrect.bottom;
    var trRadiusX = rrect.trRadiusX.abs();
    var tlRadiusX = rrect.tlRadiusX.abs();
    var trRadiusY = rrect.trRadiusY.abs();
    var tlRadiusY = rrect.tlRadiusY.abs();
    var blRadiusX = rrect.blRadiusX.abs();
    var brRadiusX = rrect.brRadiusX.abs();
    var blRadiusY = rrect.blRadiusY.abs();
    var brRadiusY = rrect.brRadiusY.abs();

    if (left > right) {
      left = right;
      right = rrect.left;
    }
    if (top > bottom) {
      top = bottom;
      bottom = rrect.top;
    }
    // Draw the rounded rectangle, counterclockwise.
    ctx.moveTo(right - trRadiusX, top);

    if (startNewPath) {
      ctx.beginPath();
    }

    // Top side and top-left corner
    ctx.lineTo(left + tlRadiusX, top);
    ctx.ellipse(
      left + tlRadiusX,
      top + tlRadiusY,
      tlRadiusX,
      tlRadiusY,
      0,
      1.5 * math.pi,
      1 * math.pi,
      true,
    );

    // Left side and bottom-left corner
    ctx.lineTo(left, bottom - blRadiusY);
    ctx.ellipse(
      left + blRadiusX,
      bottom - blRadiusY,
      blRadiusX,
      blRadiusY,
      0,
      1 * math.pi,
      0.5 * math.pi,
      true,
    );

    // Bottom side and bottom-right corner
    ctx.lineTo(right - brRadiusX, bottom);
    ctx.ellipse(
      right - brRadiusX,
      bottom - brRadiusY,
      brRadiusX,
      brRadiusY,
      0,
      0.5 * math.pi,
      0 * math.pi,
      true,
    );

    // Right side and top-right corner
    ctx.lineTo(right, top + trRadiusY);
    ctx.ellipse(
      right - trRadiusX,
      top + trRadiusY,
      trRadiusX,
      trRadiusY,
      0,
      0 * math.pi,
      1.5 * math.pi,
      true,
    );
  }

  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    _applyPaint(paint);
    _drawRRectPath(outer);
    _drawRRectPathReverse(inner, startNewPath: false);
    _strokeOrFill(paint);
  }

  void drawOval(Rect rect, Paint paint) {
    _applyPaint(paint);
    ctx.beginPath();
    ctx.ellipse(rect.center.dx, rect.center.dy, rect.width / 2, rect.height / 2,
        0, 0, 2.0 * math.pi, false);
    _strokeOrFill(paint);
  }

  void drawCircle(Offset c, double radius, Paint paint) {
    _applyPaint(paint);
    ctx.beginPath();
    ctx.ellipse(c.dx, c.dy, radius, radius, 0, 0, 2.0 * math.pi, false);
    _strokeOrFill(paint);
  }

  void drawPath(Path path, Paint paint) {
    _applyPaint(paint);
    _runPath(path);
    _strokeOrFill(paint);
  }

  void drawShadow(
      Path path, Color color, double elevation, bool transparentOccluder) {
    final shadows = ElevationShadow.computeCanvasShadows(elevation, color);
    if (shadows.isNotEmpty) {
      for (final shadow in shadows) {
        // We paint shadows using a path and a mask filter instead of the
        // built-in shadow* properties. This is because the color alpha of the
        // paint is added to the shadow. The effect we're looking for is to just
        // paint the shadow without the path itself, but if we use a non-zero
        // alpha for the paint the path is painted in addition to the shadow,
        // which is undesirable.
        final paint = Paint()
          ..color = shadow.color
          ..style = PaintingStyle.fill
          ..strokeWidth = 0.0
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blur);
        _ctx.save();
        _ctx.translate(shadow.offsetX, shadow.offsetY);
        _applyPaint(paint);
        _runPath(path);
        _strokeOrFill(paint, resetPaint: false);
        _ctx.restore();
      }
      _resetPaint();
    }
  }

  void drawImage(Image image, Offset p, Paint paint) {
    _applyPaint(paint);
    html.Element imgElement = (image as HtmlImage).imgElement.clone(true);
    imgElement.style
      ..position = 'absolute'
      ..transform = 'translate(${p.dx}px, ${p.dy}px)';
    rootElement.append(imgElement);
  }

  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    // TODO(het): Check if the src rect is the entire image, and if so just
    // append the imgElement and set it's height and width.
    ctx.drawImageScaledFromSource(
      (image as HtmlImage).imgElement,
      src.left,
      src.top,
      src.width,
      src.height,
      dst.left,
      dst.top,
      dst.width,
      dst.height,
    );
  }

  void drawParagraph(Paragraph paragraph, Offset offset) {
    assert(paragraph.webOnlyIsLaidOut);

    if (paragraph.webOnlyDrawOnCanvas) {
      var style = paragraph.webOnlyGetParagraphGeometricStyle();
      if (style != _cachedLastStyle) {
        ctx.font = style.cssFontString;
        _cachedLastStyle = style;
      }
      _applyPaint(paragraph.webOnlyGetPaint());
      ctx.fillText(
          paragraph.webOnlyGetPlainText(),
          offset.dx + paragraph.webOnlyAlignOffset,
          offset.dy + paragraph.alphabeticBaseline);
      _resetPaint();
      return;
    }

    // This will cause a new canvas to be created for the next painting
    // operation. This ensures that shapes that appear on top of text are
    // rendered correctly.
    // TODO(yjbanov): as our sample apps show it is a very common case for text
    //                drawing operations to interleave non-text operations,
    //                which generates a lot of HTML canvases for a single
    //                Flutter Picture. This kills performance. We need a smarter
    //                strategy, such as deducing painting bounds from paint ops
    //                and/or sinking non-intersecting graphics down the canvas
    //                chain.
    // _canvas = null;

    html.Element paragraphElement =
        paragraph.webOnlyGetParagraphElement().clone(true);
    paragraphElement.style
      ..position = 'absolute'
      ..transform =
          'translate(${offset.dx - bounds.left}px, ${offset.dy - bounds.top}px)'
      ..whiteSpace = 'pre-wrap'
      ..width = '${paragraph.width}px'
      ..height = '${paragraph.height}px';
    rootElement.append(paragraphElement);
    _paragraphs.add(paragraphElement);
  }

  /// Paints the [picture] into this canvas.
  void drawPicture(Picture picture) {
    picture.recordingCanvas.apply(this, clearFirst: false);
  }

  /// 'Runs' the given [path] by applying all of its commands to the canvas.
  void _runPath(Path path) {
    ctx.beginPath();
    for (var subpath in path.subpaths) {
      for (var command in subpath.commands) {
        switch (command.type) {
          case PathCommandTypes.bezierCurveTo:
            BezierCurveTo curve = command;
            ctx.bezierCurveTo(
                curve.x1, curve.y1, curve.x2, curve.y2, curve.x3, curve.y3);
            break;
          case PathCommandTypes.close:
            ctx.closePath();
            break;
          case PathCommandTypes.ellipse:
            Ellipse ellipse = command;
            ctx.ellipse(
                ellipse.x,
                ellipse.y,
                ellipse.radiusX,
                ellipse.radiusY,
                ellipse.rotation,
                ellipse.startAngle,
                ellipse.endAngle,
                ellipse.anticlockwise);
            break;
          case PathCommandTypes.lineTo:
            LineTo lineTo = command;
            ctx.lineTo(lineTo.x, lineTo.y);
            break;
          case PathCommandTypes.moveTo:
            MoveTo moveTo = command;
            ctx.moveTo(moveTo.x, moveTo.y);
            break;
          case PathCommandTypes.rRect:
            RRectCommand rrectCommand = command;
            _drawRRectPath(rrectCommand.rrect, startNewPath: false);
            break;
          case PathCommandTypes.rect:
            RectCommand rectCommand = command;
            ctx.rect(rectCommand.x, rectCommand.y, rectCommand.width,
                rectCommand.height);
            break;
          case PathCommandTypes.quadraticCurveTo:
            QuadraticCurveTo quadraticCurveTo = command;
            ctx.quadraticCurveTo(quadraticCurveTo.x1, quadraticCurveTo.y1,
                quadraticCurveTo.x2, quadraticCurveTo.y2);
            break;
          default:
            throw new UnimplementedError('Unknown path command $command');
        }
      }
    }
  }
}

String _stringForBlendMode(BlendMode blendMode) {
  if (blendMode == null) return null;
  switch (blendMode) {
    case BlendMode.srcOver:
      return 'source-over';
    case BlendMode.srcIn:
      return 'source-in';
    case BlendMode.srcOut:
      return 'source-out';
    case BlendMode.srcATop:
      return 'source-atop';
    case BlendMode.dstOver:
      return 'destination-over';
    case BlendMode.dstIn:
      return 'destination-in';
    case BlendMode.dstOut:
      return 'destination-out';
    case BlendMode.dstATop:
      return 'destination-atop';
    case BlendMode.plus:
      return 'lighten';
    case BlendMode.src:
      return 'copy';
    case BlendMode.xor:
      return 'xor';
    case BlendMode.multiply:
    // Falling back to multiply, ignoring alpha channel.
    // TODO(flutter_web): only used for debug, find better fallback for web.
    case BlendMode.modulate:
      return 'multiply';
    case BlendMode.screen:
      return 'screen';
    case BlendMode.overlay:
      return 'overlay';
    case BlendMode.darken:
      return 'darken';
    case BlendMode.lighten:
      return 'lighten';
    case BlendMode.colorDodge:
      return 'color-dodge';
    case BlendMode.colorBurn:
      return 'color-burn';
    case BlendMode.hardLight:
      return 'hard-light';
    case BlendMode.softLight:
      return 'soft-light';
    case BlendMode.difference:
      return 'difference';
    case BlendMode.exclusion:
      return 'exclusion';
    case BlendMode.hue:
      return 'hue';
    case BlendMode.saturation:
      return 'saturation';
    case BlendMode.color:
      return 'color';
    case BlendMode.luminosity:
      return 'luminosity';
    default:
      throw new UnimplementedError(
          'Flutter Web does not support the blend mode: $blendMode');
  }
}

String _stringForStrokeCap(StrokeCap strokeCap) {
  if (strokeCap == null) return null;
  switch (strokeCap) {
    case StrokeCap.butt:
      return 'butt';
    case StrokeCap.round:
      return 'round';
    case StrokeCap.square:
    default:
      return 'square';
  }
}
