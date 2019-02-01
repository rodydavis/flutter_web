// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'painting.dart';
import 'util.dart';

class HtmlCodec implements Codec {
  final String src;

  HtmlCodec(this.src);

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => 0;

  @override
  Future<FrameInfo> getNextFrame() async {
    StreamSubscription subscription;
    StreamSubscription errorSubscription;
    final completer = Completer<FrameInfo>();
    final html.ImageElement imgElement = html.ImageElement();
    subscription = imgElement.onLoad.listen((_) {
      subscription.cancel();
      errorSubscription.cancel();
      final image = HtmlImage(
        imgElement,
        imgElement.naturalWidth,
        imgElement.naturalHeight,
      );
      completer.complete(SingleFrameInfo(image));
    });
    errorSubscription = imgElement.onError.listen((e) {
      subscription.cancel();
      errorSubscription.cancel();
      completer.completeError(e);
    });
    imgElement.src = src;
    return completer.future;
  }

  @override
  void dispose() {}
}

class HtmlBlobCodec extends HtmlCodec {
  final html.Blob blob;

  HtmlBlobCodec(this.blob) : super(html.Url.createObjectUrlFromBlob(blob));

  @override
  void dispose() {
    html.Url.revokeObjectUrl(src);
  }
}

class SingleFrameInfo implements FrameInfo {
  SingleFrameInfo(this.image);

  @override
  Duration get duration => const Duration(milliseconds: 0);

  @override
  final Image image;
}

class HtmlImage implements Image {
  final html.ImageElement imgElement;

  HtmlImage(this.imgElement, this.width, this.height);

  @override
  void dispose() {
    // Do nothing. The codec that owns this image should take care of
    // releasing the object url.
  }

  @override
  final int width;

  @override
  final int height;

  @override
  Future<ByteData> toByteData(
      {ImageByteFormat format = ImageByteFormat.rawRgba}) {
    return futurize((Callback<ByteData> callback) {
      return _toByteData(format.index, (Uint8List encoded) {
        callback(encoded?.buffer?.asByteData());
      });
    });
  }

  /// Returns an error message on failure, null on success.
  String _toByteData(int format, Callback<Uint8List> callback) => null;
}
