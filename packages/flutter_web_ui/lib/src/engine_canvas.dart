// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'canvas.dart';
import 'geometry.dart';
import 'painting.dart';
import 'text.dart';

/// Defines canvas interface common across canvases that the [SceneBuilder]
/// renders to.
///
/// This can be used either as an interface or super-class.
abstract class EngineCanvas {
  /// The element that is attached to the DOM.
  html.Element get rootElement;

  void clear();

  void save();

  void restore();

  void translate(double dx, double dy);

  void scale(double sx, double sy);

  void rotate(double radians);

  void skew(double sx, double sy);

  void transform(Float64List matrix4);

  void clipRect(Rect rect);

  void clipRRect(RRect rrect);

  void clipPath(Path path);

  void drawColor(Color color, BlendMode blendMode);

  void drawLine(Offset p1, Offset p2, Paint paint);

  void drawPaint(Paint paint);

  void drawRect(Rect rect, Paint paint);

  void drawRRect(RRect rrect, Paint paint);

  void drawDRRect(RRect outer, RRect inner, Paint paint);

  void drawOval(Rect rect, Paint paint);

  void drawCircle(Offset c, double radius, Paint paint);

  void drawPath(Path path, Paint paint);

  void drawShadow(
      Path path, Color color, double elevation, bool transparentOccluder);

  void drawImage(Image image, Offset p, Paint paint);

  void drawImageRect(Image image, Rect src, Rect dst, Paint paint);

  void drawParagraph(Paragraph paragraph, Offset offset);
}

/// Adds an [offset] transformation to a [transform] matrix and returns the
/// combined result.
///
/// If the given offset is zero, returns [transform] matrix as is. Otherwise,
/// returns a new [Matrix4] object representing the combined transformation.
Matrix4 transformWithOffset(Matrix4 transform, Offset offset) {
  if (offset == Offset.zero) {
    return transform;
  }

  // Clone to avoid mutating transform.
  Matrix4 effectiveTransform = transform.clone();
  effectiveTransform.translate(offset.dx, offset.dy, 0.0);
  return effectiveTransform;
}

class _SaveStackEntry {
  _SaveStackEntry({this.savedElement, this.transform});

  final html.Element savedElement;
  final Matrix4 transform;
}

/// Provides save stack tracking functionality to implementations of
/// [EngineCanvas].
mixin SaveStackTracking on EngineCanvas {
  static final Vector3 _unitZ = Vector3(0.0, 0.0, 1.0);

  final List<_SaveStackEntry> _saveStack = <_SaveStackEntry>[];

  /// The element at the top of the element stack, or [rootElement] if the stack
  /// is empty.
  html.Element get currentElement =>
      _elementStack.isEmpty ? rootElement : _elementStack.last;

  /// The stack that maintains the DOM elements used to express certain paint
  /// operations, such as clips.
  final List<html.Element> _elementStack = <html.Element>[];

  /// Pushes the [element] onto the element stack for the purposes of applying
  /// a paint effect using a DOM element, e.g. for clipping.
  ///
  /// The [restore] method automatically pops the element off the stack.
  void pushElement(html.Element element) {
    _elementStack.add(element);
  }

  /// Empties the save stack and the element stack, and resets the transform
  /// and clip parameters.
  ///
  /// Classes that override this method must call `super.clear()`.
  void clear() {
    _saveStack.clear();
    _elementStack.clear();
    _currentTransform = Matrix4.identity();
  }

  /// The current transformation matrix.
  Matrix4 get currentTransform => _currentTransform;
  Matrix4 _currentTransform = Matrix4.identity();

  /// Saves current clip and transform on the save stack.
  ///
  /// Classes that override this method must call `super.save()`.
  void save() {
    _saveStack.add(_SaveStackEntry(
      savedElement: currentElement,
      transform: _currentTransform.clone(),
    ));
  }

  /// Restores current clip and transform from the save stack.
  ///
  /// Classes that override this method must call `super.restore()`.
  void restore() {
    if (_saveStack.isEmpty) {
      return;
    }
    final _SaveStackEntry entry = _saveStack.removeLast();
    _currentTransform = entry.transform;

    // Pop out of any clips.
    while (currentElement != entry.savedElement) {
      _elementStack.removeLast();
    }
  }

  /// Multiplies the [currentTransform] matrix by a translation.
  ///
  /// Classes that override this method must call `super.translate()`.
  void translate(double dx, double dy) {
    _currentTransform.translate(dx, dy);
  }

  /// Scales the [currentTransform] matrix.
  ///
  /// Classes that override this method must call `super.scale()`.
  void scale(double sx, double sy) {
    _currentTransform.scale(sx, sy);
  }

  /// Rotates the [currentTransform] matrix.
  ///
  /// Classes that override this method must call `super.rotate()`.
  void rotate(double radians) {
    _currentTransform.rotate(_unitZ, radians);
  }

  /// Skews the [currentTransform] matrix.
  ///
  /// Classes that override this method must call `super.skew()`.
  void skew(double sx, double sy) {
    _currentTransform.multiply(Matrix4.skew(sx, sy));
  }

  /// Multiplies the [currentTransform] matrix by another matrix.
  ///
  /// Classes that override this method must call `super.transform()`.
  void transform(Float64List matrix4) {
    _currentTransform.multiply(Matrix4.fromFloat64List(matrix4));
  }
}
