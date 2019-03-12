// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web/material.dart';
import 'package:flutter_web_test/flutter_web_test.dart';
import 'package:flutter_web_test/scuba_test.dart';

void main() async {
  final scuba = await initializeScuba(devicePixelRatio: 1.0);

  testWidgets('draws line with varying strokeWidth',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      new CustomPaint(
        painter: ThicknessCustomPainter(),
        size: Size(300, 300),
      ),
    );
    await scuba.diffScreenshot(tester, 'draw_lines_thickness');
  });
}

class ThicknessCustomPainter extends CustomPainter {
  ThicknessCustomPainter({this.log, this.name});

  final List<String> log;
  final String name;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = new Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final paint2 = new Paint()
      ..color = Color(0x7fff0000)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final paint3 = new Paint()
      ..color = Colors.green
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    // Draw markers around 100x100 box
    canvas.drawLine(Offset(50, 50), Offset(52, 50), paint1);
    canvas.drawLine(Offset(150, 50), Offset(148, 50), paint1);
    canvas.drawLine(Offset(50, 150), Offset(52, 150), paint1);
    canvas.drawLine(Offset(150, 150), Offset(148, 150), paint1);
    // Draw diagonal
    canvas.drawLine(Offset(50, 50), Offset(150, 150), paint2);
    // Draw horizontal
    paint3.strokeWidth = 1.0;
    paint3.color = Color(0xFFFF0000);
    canvas.drawLine(Offset(50, 55), Offset(150, 55), paint3);
    paint3.strokeWidth = 2.0;
    paint3.color = Colors.blue;
    canvas.drawLine(Offset(50, 60), Offset(150, 60), paint3);
    paint3.strokeWidth = 4.0;
    paint3.color = Colors.orange;
    canvas.drawLine(Offset(50, 70), Offset(150, 70), paint3);
  }

  @override
  bool shouldRepaint(ThicknessCustomPainter oldPainter) => true;
}
