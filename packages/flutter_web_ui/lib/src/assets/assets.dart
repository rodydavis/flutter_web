// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

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
      var request =
          await html.HttpRequest.request(url, responseType: 'arraybuffer');

      return (request.response as ByteBuffer).asByteData();
    } on html.ProgressEvent catch (e) {
      if (e.target is html.HttpRequest) {
        throw AssetManagerException(url, (e.target as html.HttpRequest).status);
      }

      rethrow;
    }
  }
}

class AssetManagerException implements Exception {
  final String url;
  final int httpStatus;

  AssetManagerException(this.url, this.httpStatus);

  @override
  String toString() => 'Failed to load asset at "$url" ($httpStatus)';
}
