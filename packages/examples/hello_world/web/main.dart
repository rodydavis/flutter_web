// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter_web_ui/ui.dart' as ui;
import 'package:flutter_web_ui/src/assets/assets.dart';
import 'package:flutter_web_ui/src/assets/fonts.dart';
import 'package:flutter_web.examples.hello_world/main.dart' as app;

main() async {
  ui.webOnlyAssetManager = AssetManager();
  // TODO(het): This loads all fonts before starting the app. We should
  // find a smarter way to load the fonts on demand.
  await loadFonts(ui.webOnlyAssetManager);
  app.main();
}
