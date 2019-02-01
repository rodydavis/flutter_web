// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(yjbanov): optimization opportunities (see also houdini_painter.js)
// - collapse non-drawing paint operations
// - avoid producing DOM-based clips if there is no text
// - evaluate using stylesheets for static CSS properties
// - evaluate reusing houdini canvases
import 'dart:convert' as convert;
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import 'canvas.dart';
import 'dom_renderer.dart';
import 'engine_canvas.dart';
import 'geometry.dart';
import 'html_image_codec.dart';
import 'painting.dart';
import 'recording_canvas.dart';
import 'text.dart';
import 'util.dart';

class _SaveStackEntry {
  _SaveStackEntry({
    @required this.savedElement,
    @required this.transform,
  });

  final html.Element savedElement;
  final Matrix4 transform;
}

/// A canvas that renders to a combination of HTML DOM and CSS Custom Paint API.
///
/// This canvas produces paint commands for houdini_painter.js to apply. This
/// class must be kept in sync with houdini_painter.js.
class HoudiniCanvas implements EngineCanvas {
  final html.Element rootElement = new html.Element.tag('flt-houdini');

  /// A unit vector pointing in the positive Z direction.
  ///
  /// This vector must not be mutated.
  static final Vector3 _unitZ = Vector3(0.0, 0.0, 1.0);

  /// The rectangle positioned relative to the parent layer's coordinate system
  /// where this canvas paints.
  ///
  /// Painting outside the bounds of this rectangle is cropped.
  final Rect bounds;

  HoudiniCanvas(this.bounds) {
    // TODO(yjbanov): would it be faster to specify static values in a
    //                stylesheet and let the browser apply them?
    rootElement.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..width = '${bounds.size.width}px'
      ..height = '${bounds.size.height}px'
      ..backgroundImage = 'paint(flt)';
  }

  /// Prepare to reuse this canvas by clearing it's current contents.
  void clear() {
    _serializedCommands = <List>[];
    // TODO(yjbanov): we should measure if reusing old elements is beneficial.
    domRenderer.clearDom(rootElement);
  }

  /// The stack that maintains [save] and [restore] operations.
  final List<_SaveStackEntry> _saveStack = <_SaveStackEntry>[];

  /// The stack that maintains the DOM elements used to express certain paint
  /// operations, such as clips.
  final List<html.Element> _elementStack = <html.Element>[];
  html.Element get _element =>
      _elementStack.isEmpty ? rootElement : _elementStack.last;

  /// Current transform.
  ///
  /// This field is _mutable_. When saving the transform on the [_saveStack] it
  /// must be copied to avoid side-effects.
  Matrix4 _transform = Matrix4.identity();

  /// Paint commands serialized for sending to the CSS custom painter.
  List<List> _serializedCommands = <List>[];

  void apply(PaintCommand command) {
    // Some commands are applied purely in HTML DOM and do not need to be
    // serialized.
    if (command is! PaintDrawParagraph &&
        command is! PaintDrawImageRect &&
        command is! PaintTransform) {
      command.serializeToCssPaint(_serializedCommands);
    }
    command.apply(this);
  }

  /// Sends the paint commands to the CSS custom painter for painting.
  void commit() {
    if (_serializedCommands.isNotEmpty) {
      rootElement.style
          .setProperty('--flt', convert.json.encode(_serializedCommands));
    } else {
      rootElement.style.removeProperty('--flt');
    }
  }

  void save() {
    _saveStack.add(_SaveStackEntry(
      savedElement: _element,
      transform: _transform.clone(),
    ));
  }

  void restore() {
    if (_saveStack.isEmpty) {
      return;
    }
    final _SaveStackEntry entry = _saveStack.removeLast();
    _transform = entry.transform;

    // Pop out of any clips.
    while (_element != entry.savedElement) {
      _elementStack.removeLast();
    }
  }

  void translate(double dx, double dy) {
    _transform.translate(dx, dy);
  }

  void scale(double sx, double sy) {
    _transform.scale(sx, sy);
  }

  void rotate(double radians) {
    _transform.rotate(_unitZ, radians);
  }

  void skew(double sx, double sy) {
    throw UnimplementedError();
  }

  // TODO(yjbanov): this is wrong. It has been inherited from BitmapCanvas
  //                that doesn't fully implement it. For example, it does not
  //                support nested transforms. It also breaks when transform is
  //                preceded by other ops.
  void transform(Float64List matrix4) {
    _element.style.transformOrigin = '0 0 0';
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
      _element.style.transform = 'translate($tx, $ty)';
    } else {
      // TODO(flutter_web): detect pure scale+translate to replace hack below.
      _element.style.transform = float64ListToCssTransform(matrix4);
    }
  }

  void clipRect(Rect rect) {
    final clip = html.Element.tag('flt-clip-rect');
    clip.style
      ..overflow = 'hidden'
      ..position = 'absolute'
      ..transform = _computeEffectiveCssTranformWithOffset(rect.left, rect.top)
      ..width = '${rect.width}px'
      ..height = '${rect.height}px';
    _transform = Matrix4.translationValues(-rect.left, -rect.top, 0.0);
    _element.append(clip);
    _elementStack.add(clip);
  }

  void clipRRect(RRect rrect) {
    final outer = rrect.outerRect;
    if (rrect.isRect) {
      clipRect(outer);
      return;
    }

    final clip = html.Element.tag('flt-clip-rrect');
    final style = clip.style;
    style
      ..overflow = 'hidden'
      ..position = 'absolute'
      ..transform = 'translate(${outer.left}px, ${outer.right}px)'
      ..width = '${outer.width}px'
      ..height = '${outer.height}px';

    if (rrect.tlRadiusY == rrect.tlRadiusX) {
      style.borderTopLeftRadius = '${rrect.tlRadiusX}px';
    } else {
      style.borderTopLeftRadius = '${rrect.tlRadiusX}px ${rrect.tlRadiusY}px';
    }

    if (rrect.trRadiusY == rrect.trRadiusX) {
      style.borderTopRightRadius = '${rrect.trRadiusX}px';
    } else {
      style.borderTopRightRadius = '${rrect.trRadiusX}px ${rrect.trRadiusY}px';
    }

    if (rrect.brRadiusY == rrect.brRadiusX) {
      style.borderBottomRightRadius = '${rrect.brRadiusX}px';
    } else {
      style.borderBottomRightRadius =
          '${rrect.brRadiusX}px ${rrect.brRadiusY}px';
    }

    if (rrect.blRadiusY == rrect.blRadiusX) {
      style.borderBottomLeftRadius = '${rrect.blRadiusX}px';
    } else {
      style.borderBottomLeftRadius =
          '${rrect.blRadiusX}px ${rrect.blRadiusY}px';
    }

    _element.append(clip);
    _elementStack.add(clip);
  }

  void clipPath(Path path) {
    // TODO(yjbanov): implement.
  }

  void drawColor(Color color, BlendMode blendMode) {
    // Drawn using CSS Paint.
  }

  void drawLine(Offset p1, Offset p2, Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawPaint(Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawRect(Rect rect, Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawRRect(RRect rrect, Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawOval(Rect rect, Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawCircle(Offset c, double radius, Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawPath(Path path, Paint paint) {
    // Drawn using CSS Paint.
  }

  void drawShadow(
      Path path, Color color, double elevation, bool transparentOccluder) {
    // Drawn using CSS Paint.
  }

  void drawImage(Image image, Offset p, Paint paint) {
    // TODO(yjbanov): implement.
  }

  String _computeEffectiveCssTranformWithOffset(double dx, double dy) {
    Matrix4 effectiveTransform = _transform;
    if (dx != 0.0 || dy != 0.0) {
      // Clone to avoid mutating _transform.
      effectiveTransform = effectiveTransform.clone();
      effectiveTransform.translate(dx, dy, 0.0);
    }
    return matrix4ToCssTransform(effectiveTransform);
  }

  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    // TODO(yjbanov): implement src rectangle
    HtmlImage htmlImage = image;
    html.Element imageBox = html.Element.tag('flt-img');
    imageBox.style
      ..position = 'absolute'
      ..transformOrigin = '0 0 0'
      ..width = '${dst.width.toInt()}px'
      ..height = '${dst.height.toInt()}px'
      ..transform = _computeEffectiveCssTranformWithOffset(dst.left, dst.top)
      ..backgroundImage = 'url(${htmlImage.imgElement.src})'
      ..backgroundRepeat = 'norepeat'
      ..backgroundSize = '${dst.width}px ${dst.height}px';
    _element.append(imageBox);
  }

  void drawParagraph(Paragraph paragraph, Offset offset) {
    html.Element paragraphElement =
        paragraph.webOnlyGetParagraphElement().clone(true);
    paragraphElement.style
      ..position = 'absolute'
      ..transformOrigin = '0 0 0'
      ..transform = _computeEffectiveCssTranformWithOffset(offset.dx, offset.dy)
      ..whiteSpace = paragraph.webOnlyDrawOnCanvas ? 'nowrap' : 'pre-wrap'
      ..width = '${paragraph.width}px'
      ..height = '${paragraph.height}px';
    _element.append(paragraphElement);
  }
}
