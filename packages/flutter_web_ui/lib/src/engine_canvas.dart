// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:typed_data';

import 'canvas.dart';
import 'geometry.dart';
import 'painting.dart';
import 'text.dart';

/// A common interface across canvases that the [SceneBuilder] renders to.
abstract class EngineCanvas {
  /// This is a pure interface.
  factory EngineCanvas._() => null;

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
