// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web/material.dart';
import 'package:flutter_web_test/flutter_web_test.dart';
import 'package:flutter_web_test/scuba_test.dart';

void main() async {
  final scuba = await initializeScuba();

  testWidgets('Bordered Container insets its child',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(
                color: Color(0x7FFF0000),
              ),
            ),
            child: Text(
              'Hello World',
              style: TextStyle(
                fontSize: 24,
                fontFamily: 'Roboto Mono',
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
    await scuba.diffScreenshot(tester, 'box_decoration_bordered_container');
  }, timeout: Timeout(Duration(seconds: 10)));
}
