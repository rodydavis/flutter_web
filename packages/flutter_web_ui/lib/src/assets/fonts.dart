// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json, utf8;
import 'dart:html' show FontFace, document, window;
import 'dart:typed_data';

import 'assets.dart';

/// Loads the fonts specified in 'FontManifest.json'.
///
/// 'FontManifest.json' is structured like so:
///
/// ```json
/// [{
///   "family": "Raleway",
///   "fonts": [{
///     "asset": "fonts/Raleway-Regular.ttf"
///   }, {
//      "asset": "fonts/Raleway-Italic.ttf",
//      "style": "italic"
//    }]
/// }, {
///   "family": "RobotoMono",
///   "fonts": [{
///     "asset": "fonts/RobotoMono-Regular.ttf"
///   }, {
///     "asset": "fonts/RobotoMono-Bold.ttf",
///     "weight": 700
///   }]
/// }]
/// ```
Future<void> loadFonts(AssetManager assetManager) async {
  ByteData byteData;

  try {
    byteData = await assetManager.load('FontManifest.json');
  } on AssetManagerException catch (e) {
    if (e.httpStatus == 404) {
      window.console
          .warn('Font manifest does not exist at `${e.url}` – ignoring.');
    } else {
      rethrow;
    }
  }

  if (byteData == null) {
    // TODO(het): Issue a warning.
    return;
  }

  List fontManifest = json.decode(utf8.decode(byteData.buffer.asUint8List()));
  if (fontManifest == null) {
    // TODO(het): Issue a warning.
    return;
  }

  var futures = <Future<FontFace>>[];

  for (Map<String, dynamic> fontFamily in fontManifest) {
    String family = fontFamily['family'];
    List fontAssets = fontFamily['fonts'];

    for (Map<String, dynamic> fontAsset in fontAssets) {
      String asset = fontAsset['asset'];
      var descriptors = <String, String>{};
      for (var descriptor in fontAsset.keys) {
        if (descriptor != 'asset') {
          descriptors[descriptor] = '${fontAsset[descriptor]}';
        }
      }
      futures.add(loadFont(
        family,
        'url(${assetManager.getAssetUrl(asset)})',
        descriptors,
      ));
    }
  }

  await Future.wait(futures);
}

/// Given a font [family] and a [source], load the font using the web's
/// [FontFace] API. The arguments are passed directly to the [FontFace]
/// constructor which is documented here:
/// https://developer.mozilla.org/en-US/docs/Web/API/FontFace
///
/// Returns a future that completes when the font is loaded and ready to use.
Future<void> loadFont(String family, String source,
    [Map<String, String> descriptors]) {
  var fontFace = FontFace(family, source, descriptors);
  document.fonts.add(fontFace);
  return fontFace.load();
}
