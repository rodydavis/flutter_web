// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_web_ui/ui.dart' as ui;
import 'package:dart.testing.screendiffing.scuba/html.dart';
import 'package:ads.acx2.testing.scuba/configuration.dart';

/// Scuba test harness for testing the engine without the framework.
///
/// This tester does not include anything related to the framework. To write
/// a Scuba test that includes the Flutter framework use the harness available
/// at `//third_party/dart/flutter_web_test/lib/scuba_test.dart`.
class EngineScubaTester {
  /// The size of the browser window used in this scuba test.
  final ui.Size viewportSize;

  final Scuba _scuba;

  EngineScubaTester(this.viewportSize, this._scuba);

  static Future<EngineScubaTester> initialize(
      {ui.Size viewportSize: const ui.Size(2400, 1800)}) async {
    assert(viewportSize != null);

    assert(() {
      if (viewportSize.width.ceil() != viewportSize.width ||
          viewportSize.height.ceil() != viewportSize.height) {
        throw Exception(
            'Scuba only supports integer screen sizes, but found: ${viewportSize}');
      }
      if (viewportSize.width < 472) {
        throw Exception('Scuba does not support screen width smaller than 472');
      }
      return true;
    }());

    var scuba = await configureAcxScuba(
      options: ComparisonOptions(allowableNumberPixelsDifferent: 10),
    );
    await scuba.setViewport(
        viewportSize.width.ceil(), viewportSize.height.ceil());
    return new EngineScubaTester(viewportSize, scuba);
  }

  Future<void> diffScreenshot(String fileName) async {
    await _scuba.diffScreenshot(fileName);
  }
}
