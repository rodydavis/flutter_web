// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_web_ui/ui.dart' hide TextStyle;
import 'package:flutter_web_ui/src/recording_canvas.dart';
import 'package:flutter_web_test/flutter_web_test.dart';

void main() {
  final screenWidth = 600.0;
  final screenHeight = 800.0;
  final screenRect = Rect.fromLTWH(0, 0, screenWidth, screenHeight);
  final testPaint = new Paint()..color = Color(0xFFFF0000);

  test('Empty canvas reports correct paint bounds', () {
    RecordingCanvas rc = new RecordingCanvas(new Rect.fromLTWH(1, 2, 300, 400));
    expect(rc.computePaintBounds(), Rect.zero);
  });

  test('Computes paint bounds for draw line', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawLine(Offset(50, 100), Offset(120, 140), testPaint);
    // The off by one is due to the minimum stroke width of 1.
    expect(rc.computePaintBounds(), Rect.fromLTRB(49, 99, 121, 141));
  });

  test('Computes paint bounds for draw line when line exceeds limits', () {
    // Uses max bounds when computing paint bounds
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawLine(Offset(50, 100), Offset(screenWidth + 100.0, 140), testPaint);
    // The off by one is due to the minimum stroke width of 1.
    expect(
        rc.computePaintBounds(), Rect.fromLTRB(49.0, 99.0, screenWidth, 141.0));
  });

  test('Computes paint bounds for draw rect', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawRect(Rect.fromLTRB(10, 20, 30, 40), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(10, 20, 30, 40));
  });

  test('Computes paint bounds for draw rect when exceeds limits', () {
    // Uses max bounds when computing paint bounds
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawRect(
        Rect.fromLTRB(10, 20, 30 + screenWidth, 40 + screenHeight), testPaint);
    expect(rc.computePaintBounds(),
        Rect.fromLTRB(10, 20, screenWidth, screenHeight));

    rc = new RecordingCanvas(screenRect);
    rc.drawRect(Rect.fromLTRB(-200, -100, 30, 40), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(0, 0, 30, 40));
  });

  test('Computes paint bounds for translate', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.translate(5, 7);
    rc.drawRect(Rect.fromLTRB(10, 20, 30, 40), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(15, 27, 35, 47));
  });

  test('Computes paint bounds for scale', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.scale(2, 2);
    rc.drawRect(Rect.fromLTRB(10, 20, 30, 40), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(20, 40, 60, 80));
  });

  test('Computes paint bounds for rotate', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.rotate(math.pi / 4.0);
    rc.drawLine(Offset(1, 0), Offset(50 * math.sqrt(2) - 1, 0), testPaint);
    // The extra 0.7 is due to stroke width of 1 rotated by 45 degrees.
    expect(rc.computePaintBounds(),
        within(distance: 0.1, from: Rect.fromLTRB(0, 0, 50.7, 50.7)));
  });

  test('Computes paint bounds for horizontal skew', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.skew(1.0, 0.0);
    rc.drawRect(Rect.fromLTRB(20, 20, 40, 40), testPaint);
    expect(rc.computePaintBounds(),
        within(distance: 0.1, from: Rect.fromLTRB(40.0, 20.0, 80.0, 40.0)));
  });

  test('Computes paint bounds for vertical skew', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.skew(0.0, 1.0);
    rc.drawRect(Rect.fromLTRB(20, 20, 40, 40), testPaint);
    expect(rc.computePaintBounds(),
        within(distance: 0.1, from: Rect.fromLTRB(20.0, 40.0, 40.0, 80.0)));
  });

  test('Computes paint bounds for transform', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    var matrix = new Float64List(16);
    // translate(210, 220) , scale(2, 3), rotate(math.pi / 4.0)
    matrix[0] = 1.4;
    matrix[1] = 2.12;
    matrix[2] = 0.0;
    matrix[3] = 0.0;
    matrix[4] = -1.4;
    matrix[5] = 2.12;
    matrix[6] = 0.0;
    matrix[7] = 0.0;
    matrix[8] = 0.0;
    matrix[9] = 0.0;
    matrix[10] = 2.0;
    matrix[11] = 0.0;
    matrix[12] = 210.0;
    matrix[13] = 220.0;
    matrix[14] = 0.0;
    matrix[15] = 1.0;
    rc.transform(matrix);
    rc.drawRect(Rect.fromLTRB(10, 20, 30, 40), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(168.0, 283.6, 224.0, 368.4));
  });

  test('drawPaint should cover full size', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawPaint(testPaint);
    rc.drawRect(Rect.fromLTRB(10, 20, 30, 40), testPaint);
    expect(rc.computePaintBounds(), screenRect);
  });

  test('drawColor should cover full size', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawColor(Color(0xFFFF0000), BlendMode.multiply);
    rc.drawRect(Rect.fromLTRB(10, 20, 30, 40), testPaint);
    expect(rc.computePaintBounds(), screenRect);
  });

  test('Computes paint bounds for draw oval', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawOval(Rect.fromLTRB(10, 20, 30, 40), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(10, 20, 30, 40));
  });

  test('Computes paint bounds for draw round rect', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(10, 20, 30, 40), Radius.circular(5.0)),
        testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(10, 20, 30, 40));
  });

  test('Computes paint bounds using outer rect for drawDRRect', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawDRRect(RRect.fromRectAndCorners(Rect.fromLTRB(10, 20, 30, 40)),
        RRect.fromRectAndCorners(Rect.fromLTRB(1, 2, 3, 4)), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(10, 20, 30, 40));
  });

  test('Computes paint bounds for draw circle', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawCircle(Offset(50, 100), 30.0, testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(20.0, 70.0, 80.0, 130.0));
    rc.drawCircle(Offset(400, 100), 300.0, testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(20.0, 0.0, 600.0, 400.0));
  });

  test('Computes paint bounds for draw image', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawImage(new TestImage(), Offset(50, 100), new Paint());
    expect(rc.computePaintBounds(), Rect.fromLTRB(50.0, 100.0, 70.0, 110.0));
  });

  test('Computes paint bounds for draw image rect', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.drawImageRect(new TestImage(), Rect.fromLTRB(1, 1, 20, 10),
        Rect.fromLTRB(5, 6, 400, 500), new Paint());
    expect(rc.computePaintBounds(), Rect.fromLTRB(5.0, 6.0, 400.0, 500.0));
  });

  // drawParagraph
  test('Computes paint bounds for draw paragraph', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    Paragraph paragraph = createTestParagraph();
    var textLeft = 5.0;
    var textTop = 7.0;
    paragraph.layout(ParagraphConstraints(width: screenWidth - textLeft));
    rc.drawParagraph(paragraph, new Offset(textLeft, textTop));
    expect(
        rc.computePaintBounds(), Rect.fromLTRB(textLeft, textTop, 600.0, 35.0));
  });

  test('Should exclude painting outside clipRect', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.clipRect(Rect.fromLTRB(50, 50, 100, 100));
    rc.drawLine(Offset(10, 11), Offset(20, 21), testPaint);

    expect(rc.computePaintBounds(), Rect.zero);
    rc.drawLine(Offset(52, 53), Offset(55, 56), testPaint);

    // Extra pixel due to default line length
    expect(rc.computePaintBounds(), Rect.fromLTRB(51, 52, 56, 57));
  });

  test('Should include range inside clipRect', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.clipRect(Rect.fromLTRB(50, 50, 100, 100));
    rc.drawRect(Rect.fromLTRB(20, 60, 120, 70), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(50, 60, 100, 70));

    rc = new RecordingCanvas(screenRect);
    rc.clipRect(Rect.fromLTRB(50, 50, 100, 100));
    rc.drawRect(Rect.fromLTRB(60, 20, 70, 200), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(60, 50, 70, 100));
  });

  test('Should intersect rects for multiple clipRect calls', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    rc.clipRect(Rect.fromLTRB(50, 50, 100, 100));
    rc.scale(2.0, 2.0);
    rc.clipRect(Rect.fromLTRB(30, 30, 45, 45));
    rc.drawRect(Rect.fromLTRB(10, 30, 60, 35), testPaint);
    expect(rc.computePaintBounds(), Rect.fromLTRB(60, 60, 90, 70));
  });

  // drawShadow
  test('Computes paint bounds for drawShadow', () {
    RecordingCanvas rc = new RecordingCanvas(screenRect);
    Path path = new Path();
    path.addRect(Rect.fromLTRB(20, 30, 100, 110));
    rc.drawShadow(path, Color(0xFFFF0000), 2.0, false);
    expect(rc.computePaintBounds(), Rect.fromLTRB(20.0, 30.0, 106.0, 117.0));
  });

  test('Clip with negative scale reports correct paint bounds', () {
    // The following draws a filled rectangle that occupies the bottom half of
    // the canvas. Notice that both the clip and the rectangle are drawn
    // forward. What makes them appear at the bottom is the translation and a
    // vertical flip via a negative scale. This replicates the Material
    // overscroll glow effect at the bottom of a list, where it is drawn upside
    // down.
    RecordingCanvas rc = new RecordingCanvas(Rect.fromLTRB(0, 0, 100, 100));
    rc
      ..translate(0, 100)
      ..scale(1, -1)
      ..clipRect(Rect.fromLTRB(0, 0, 100, 50))
      ..drawRect(Rect.fromLTRB(0, 0, 100, 100), Paint());
    expect(rc.computePaintBounds(), Rect.fromLTRB(0.0, 50.0, 100.0, 100.0));
  });

  test('Clip with a rotation reports correct paint bounds', () {
    RecordingCanvas rc = new RecordingCanvas(Rect.fromLTRB(0, 0, 100, 100));
    rc
      ..translate(50, 50)
      ..rotate(math.pi / 4.0)
      ..clipRect(Rect.fromLTWH(-20, -20, 40, 40))
      ..drawRect(Rect.fromLTWH(-80, -80, 160, 160), Paint());
    expect(
      rc.computePaintBounds(),
      Rect.fromCircle(center: Offset(50, 50), radius: 20 * math.sqrt(2)),
    );
  });
}

class TestImage implements Image {
  @override
  int get width => 20;

  @override
  int get height => 10;

  @override
  Future<ByteData> toByteData(
      {ImageByteFormat format = ImageByteFormat.rawRgba}) async {
    throw UnsupportedError('Cannot encode test image');
  }

  @override
  String toString() => '[$width\u00D7$height]';

  @override
  void dispose() {}
}

Paragraph createTestParagraph() {
  var builder = ParagraphBuilder(ParagraphStyle(
    fontFamily: 'sans-serif',
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.normal,
    fontSize: 14.0,
  ));
  builder.addText('The quick brown fox jumps over the lazy dog?');
  return builder.build();
}
