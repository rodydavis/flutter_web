// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web/rendering.dart';
import 'package:flutter_web/material.dart';
import 'package:flutter_web/widgets.dart';
import 'package:flutter_web_ui/ui.dart';
import 'package:flutter_web_test/flutter_web_test.dart';

// TODO: Add Semantics tests.
void main() {
  testWidgets('Card margin', (WidgetTester tester) async {
    const Key contentsKey = ValueKey<String>('contents');

    await tester.pumpWidget(
      Container(
        alignment: Alignment.topLeft,
        child: Card(
          child: Container(
            key: contentsKey,
            color: const Color(0xFF00FF00),
            width: 100.0,
            height: 100.0,
          ),
        ),
      ),
    );

    // Default margin is 4
    expect(tester.getTopLeft(find.byType(Card)), const Offset(0.0, 0.0));
    expect(tester.getSize(find.byType(Card)), const Size(108.0, 108.0));

    expect(tester.getTopLeft(find.byKey(contentsKey)), const Offset(4.0, 4.0));
    expect(tester.getSize(find.byKey(contentsKey)), const Size(100.0, 100.0));

    await tester.pumpWidget(
      Container(
        alignment: Alignment.topLeft,
        child: Card(
          margin: EdgeInsets.zero,
          child: Container(
            key: contentsKey,
            color: const Color(0xFF00FF00),
            width: 100.0,
            height: 100.0,
          ),
        ),
      ),
    );

    // Specified margin is zero
    expect(tester.getTopLeft(find.byType(Card)), const Offset(0.0, 0.0));
    expect(tester.getSize(find.byType(Card)), const Size(100.0, 100.0));

    expect(tester.getTopLeft(find.byKey(contentsKey)), const Offset(0.0, 0.0));
    expect(tester.getSize(find.byKey(contentsKey)), const Size(100.0, 100.0));
  });

  testWidgets('Card clipBehavior property passes through to the Material',
      (WidgetTester tester) async {
    await tester.pumpWidget(const Card());
    expect(
        tester.widget<Material>(find.byType(Material)).clipBehavior, Clip.none);

    await tester.pumpWidget(const Card(clipBehavior: Clip.antiAlias));
    expect(tester.widget<Material>(find.byType(Material)).clipBehavior,
        Clip.antiAlias);
  });
}
