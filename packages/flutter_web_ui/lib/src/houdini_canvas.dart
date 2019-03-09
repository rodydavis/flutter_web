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

import 'canvas.dart';
import 'dom_renderer.dart';
import 'engine_canvas.dart';
import 'geometry.dart';
import 'html_image_codec.dart';
import 'painting.dart';
import 'recording_canvas.dart';
import 'text.dart';
import 'util.dart';

/// A canvas that renders to a combination of HTML DOM and CSS Custom Paint API.
///
/// This canvas produces paint commands for houdini_painter.js to apply. This
/// class must be kept in sync with houdini_painter.js.
class HoudiniCanvas extends EngineCanvas with SaveStackTracking {
  final html.Element rootElement = new html.Element.tag('flt-houdini');

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
    super.clear();
    _serializedCommands = <List>[];
    // TODO(yjbanov): we should measure if reusing old elements is beneficial.
    domRenderer.clearDom(rootElement);
  }

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

  void clipRect(Rect rect) {
    final clip = html.Element.tag('flt-clip-rect');
    String cssTransform = matrix4ToCssTransform(
        transformWithOffset(currentTransform, Offset(rect.left, rect.top)));
    clip.style
      ..overflow = 'hidden'
      ..position = 'absolute'
      ..transform = cssTransform
      ..width = '${rect.width}px'
      ..height = '${rect.height}px';

    // The clipping element will translate the coordinate system as well, which
    // is not what a clip should do. To offset that we translate in the opposite
    // direction.
    super.translate(-rect.left, -rect.top);

    currentElement.append(clip);
    pushElement(clip);
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

    // The clipping element will translate the coordinate system as well, which
    // is not what a clip should do. To offset that we translate in the opposite
    // direction.
    super.translate(-rrect.left, -rrect.top);

    currentElement.append(clip);
    pushElement(clip);
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

  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    // TODO(yjbanov): implement src rectangle
    HtmlImage htmlImage = image;
    html.Element imageBox = html.Element.tag('flt-img');
    String cssTransform = matrix4ToCssTransform(
        transformWithOffset(currentTransform, Offset(dst.left, dst.top)));
    imageBox.style
      ..position = 'absolute'
      ..transformOrigin = '0 0 0'
      ..width = '${dst.width.toInt()}px'
      ..height = '${dst.height.toInt()}px'
      ..transform = cssTransform
      ..backgroundImage = 'url(${htmlImage.imgElement.src})'
      ..backgroundRepeat = 'norepeat'
      ..backgroundSize = '${dst.width}px ${dst.height}px';
    currentElement.append(imageBox);
  }

  void drawParagraph(Paragraph paragraph, Offset offset) {
    assert(paragraph.webOnlyIsLaidOut);

    html.Element paragraphElement =
        paragraph.webOnlyGetParagraphElement().clone(true);

    String cssTransform =
        matrix4ToCssTransform(transformWithOffset(currentTransform, offset));

    paragraphElement.style
      ..position = 'absolute'
      ..transformOrigin = '0 0 0'
      ..transform = cssTransform
      ..whiteSpace = paragraph.webOnlyDrawOnCanvas ? 'nowrap' : 'pre-wrap'
      ..width = '${paragraph.width}px'
      ..height = '${paragraph.height}px';
    currentElement.append(paragraphElement);
  }
}
