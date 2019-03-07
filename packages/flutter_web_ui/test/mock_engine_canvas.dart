// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter_web_ui/src/engine_canvas.dart';
import 'package:flutter_web_ui/ui.dart';

/// Contains method name that was called on [MockEngineCanvas] and arguments
/// that were passed.
class MockCanvasCall {
  MockCanvasCall._({
    this.methodName,
    this.arguments,
  });

  final String methodName;
  final dynamic arguments;

  @override
  String toString() {
    return '$MockCanvasCall($methodName, $arguments)';
  }
}

/// A fake implementation of [EngineCanvas] that logs calls to its methods but
/// doesn't actually paint anything.
///
/// Useful for testing interactions between upper layers of the system with
/// canvases.
class MockEngineCanvas implements EngineCanvas {
  final List<MockCanvasCall> methodCallLog = <MockCanvasCall>[];

  html.Element get rootElement => null;

  void _called(String methodName, {dynamic arguments}) {
    methodCallLog.add(MockCanvasCall._(
      methodName: methodName,
      arguments: arguments,
    ));
  }

  void clear() {
    _called('clear');
  }

  void save() {
    _called('save');
  }

  void restore() {
    _called('restore');
  }

  void translate(double dx, double dy) {
    _called('translate', arguments: {
      'dx': dx,
      'dy': dy,
    });
  }

  void scale(double sx, double sy) {
    _called('scale', arguments: {
      'sx': sx,
      'sy': sy,
    });
  }

  void rotate(double radians) {
    _called('rotate', arguments: radians);
  }

  void skew(double sx, double sy) {
    _called('skew', arguments: {
      'sx': sx,
      'sy': sy,
    });
  }

  void transform(Float64List matrix4) {
    _called('transform', arguments: matrix4);
  }

  void clipRect(Rect rect) {
    _called('clipRect', arguments: rect);
  }

  void clipRRect(RRect rrect) {
    _called('clipRRect', arguments: rrect);
  }

  void clipPath(Path path) {
    _called('clipPath', arguments: path);
  }

  void drawColor(Color color, BlendMode blendMode) {
    _called('drawColor', arguments: {
      'color': color,
      'blendMode': blendMode,
    });
  }

  void drawLine(Offset p1, Offset p2, Paint paint) {
    _called('drawLine', arguments: {
      'p1': p1,
      'p2': p2,
      'paint': paint,
    });
  }

  void drawPaint(Paint paint) {
    _called('drawPaint', arguments: paint);
  }

  void drawRect(Rect rect, Paint paint) {
    _called('drawRect', arguments: paint);
  }

  void drawRRect(RRect rrect, Paint paint) {
    _called('drawRRect', arguments: {
      'rrect': rrect,
      'paint': paint,
    });
  }

  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    _called('drawDRRect', arguments: {
      'outer': outer,
      'inner': inner,
      'paint': paint,
    });
  }

  void drawOval(Rect rect, Paint paint) {
    _called('drawOval', arguments: {
      'rect': rect,
      'paint': paint,
    });
  }

  void drawCircle(Offset c, double radius, Paint paint) {
    _called('drawCircle', arguments: {
      'c': c,
      'radius': radius,
      'paint': paint,
    });
  }

  void drawPath(Path path, Paint paint) {
    _called('drawPath', arguments: {
      'path': path,
      'paint': paint,
    });
  }

  void drawShadow(
      Path path, Color color, double elevation, bool transparentOccluder) {
    _called('drawShadow', arguments: {
      'path': path,
      'color': color,
      'elevation': elevation,
      'transparentOccluder': transparentOccluder,
    });
  }

  void drawImage(Image image, Offset p, Paint paint) {
    _called('drawImage', arguments: {
      'image': image,
      'p': p,
      'paint': paint,
    });
  }

  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    _called('drawImageRect', arguments: {
      'image': image,
      'src': src,
      'dst': dst,
      'paint': paint,
    });
  }

  void drawParagraph(Paragraph paragraph, Offset offset) {
    _called('drawParagraph', arguments: {
      'paragraph': paragraph,
      'offset': offset,
    });
  }
}
