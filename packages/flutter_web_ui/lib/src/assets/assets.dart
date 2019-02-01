// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

/// This class downloads assets over the network.
///
/// The assets are resolved relative to [assetsDir].
class AssetManager {
  static const String _defaultAssetsDir = 'assets';

  /// The directory containing the assets.
  final String assetsDir;

  const AssetManager({this.assetsDir = _defaultAssetsDir});

  String getAssetUrl(String asset) {
    var assetUri = Uri.parse(asset);

    String url;

    if (assetUri.hasScheme) {
      url = asset;
    } else {
      url = '$assetsDir/$asset';
    }

    return url;
  }

  Future<ByteData> load(String asset) async {
    var url = getAssetUrl(asset);
    try {
      var request = await HttpRequest.request(url, responseType: 'arraybuffer');

      return (request.response as ByteBuffer).asByteData();
    } on ProgressEvent catch (e) {
      if (e.target is HttpRequest) {
        throw AssetManagerException._(url, (e.target as HttpRequest).status);
      }

      rethrow;
    }
  }
}

class AssetManagerException implements Exception {
  final String url;
  final int httpStatus;

  AssetManagerException._(this.url, this.httpStatus);

  @override
  String toString() => 'Failed to load asset at "$url" ($httpStatus)';
}
