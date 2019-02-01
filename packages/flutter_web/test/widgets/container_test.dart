// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web/material.dart';
import 'package:flutter_web_test/flutter_web_test.dart';

void main() {
  testWidgets('Container control test', (WidgetTester tester) async {
    await tester.pumpWidget(new Container(
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(7.0),
      // uses color, not decoration:
      color: const Color(0xFF00FF00),
      foregroundDecoration: const BoxDecoration(color: const Color(0x7F0000FF)),
      width: 53.0,
      height: 76.0,
      constraints: const BoxConstraints(
        minWidth: 50.0,
        maxWidth: 55.0,
        minHeight: 78.0,
        maxHeight: 82.0,
      ),
      margin: const EdgeInsets.all(5.0),
      child: const SizedBox(
        width: 25.0,
        height: 33.0,
        child: const DecoratedBox(
          // uses decoration, not color:
          decoration: const BoxDecoration(color: const Color(0xFFFFFF00)),
          child: const Text('', textDirection: TextDirection.ltr),
        ),
      ),
    ));

    RenderBox box = tester.renderObject(find.byType(Container));
    expect(box.size, Size(800.0, 600.0));
  });
}
