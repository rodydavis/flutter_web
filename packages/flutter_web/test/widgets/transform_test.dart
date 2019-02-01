// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web/material.dart';
import 'package:flutter_web_test/flutter_web_test.dart';

import '../rendering/mock_canvas.dart';

void main() {
  group('$Transform', () {
    testWidgets('sets transform matrix', (WidgetTester tester) async {
      final matrix = Matrix4(1.05, 2.05, 3.05, 4.05, 5.05, 6.05, 7.05, 8.05,
          9.05, 10.05, 11.05, 12.05, 13.05, 14.05, 15.05, 16.05);
      await tester.pumpWidget(new Transform(
        transform: matrix,
        child: CustomPaint(
          painter: _TestPainter(),
        ),
      ));
      expectCurrentLayout('''
<pic style="transform: translate(0px, 0px)">
  <c style="transform: translate(6px, 5px)">
    <canvas style="width: 36px;
                   height: 48px;
                   transform-origin: 0px 0px 0px;
                   transform: matrix3d(${matrix.storage.join(', ')})">
    </canvas>
  </c>
</pic>
      ''');
    });

    testWidgets('translates canvas when purely translated',
        (WidgetTester tester) async {
      final matrix = Matrix4.translationValues(1.0, 1.0, 0.0);
      await tester.pumpWidget(new Transform(
        transform: matrix,
        child: CustomPaint(
          painter: _TestPainter(),
        ),
      ));
      expectCurrentLayout('''
<pic style="transform: translate(0px, 0px)">
  <c>
    <canvas style="width: 6px; height: 6px"></canvas>
  </c>
</pic>
      ''');

      expect(
        find.byType(Transform),
        paints
          ..translate(x: 1.0, y: 1.0)
          ..circle(x: 0.0, y: 0.0, radius: 1.0),
      );
    });
  });
}

class _TestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(0.0, 0.0), 1.0, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
