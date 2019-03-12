import 'dart:async';

import 'package:ads.acx2.testing.scuba/configuration.dart';
import 'package:dart.testing.screendiffing.scuba/html.dart';
import 'package:flutter_web/material.dart';
import 'src/widget_tester.dart';

/// Manages Scuba instance and viewport for Flutter Web tests.
///
/// Usage:
///   In main() async {
///     var scuba = await initializeScuba();
///   In testWidgets( () {
///     pumpWidget...
///     await scuba.diffScreenshot(tester, 'file_name_without_extension')
class ScubaTester {
  final Scuba _scuba;
  ScubaTester(this._scuba);

  Future<void> diffScreenshot(WidgetTester tester, String fileName) async {
    await tester.runAsync(() async {
      await _scuba.diffScreenshot(fileName);
    }, additionalTime: Duration(seconds: 10));
  }
}

Future<ScubaTester> initializeScuba(
    {Size viewportSize = const Size(800, 600),
    double devicePixelRatio = 3.0}) async {
  webOnlyInitializeTestDomRenderer(devicePixelRatio: devicePixelRatio);
  var scuba = await configureAcxScuba(
      options: ComparisonOptions(allowableNumberPixelsDifferent: 10));
  await scuba.setViewport(
      (viewportSize.width * devicePixelRatio).ceil().toInt(),
      (viewportSize.height * devicePixelRatio).ceil().toInt());
  return new ScubaTester(scuba);
}
