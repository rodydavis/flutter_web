// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

/// Generic callback signature, used by [_futurize].
typedef Callback<T> = void Function(T result);

/// Signature for a method that receives a [_Callback].
///
/// Return value should be null on success, and a string error message on
/// failure.
typedef Callbacker<T> = String Function(Callback<T> callback);

/// Converts a method that receives a value-returning callback to a method that
/// returns a Future.
///
/// Return a [String] to cause an [Exception] to be synchronously thrown with
/// that string as a message.
///
/// If the callback is called with null, the future completes with an error.
///
/// Example usage:
///
/// ```dart
/// typedef IntCallback = void Function(int result);
///
/// String _doSomethingAndCallback(IntCallback callback) {
///   new Timer(new Duration(seconds: 1), () { callback(1); });
/// }
///
/// Future<int> doSomething() {
///   return _futurize(_doSomethingAndCallback);
/// }
/// ```
Future<T> futurize<T>(Callbacker<T> callbacker) {
  final Completer<T> completer = new Completer<T>.sync();
  final String error = callbacker((T t) {
    if (t == null) {
      completer.completeError(new Exception('operation failed'));
    } else {
      completer.complete(t);
    }
  });
  if (error != null) throw new Exception(error);
  return completer.future;
}

/// Converts [matrix] to CSS transform value.
String matrix4ToCssTransform(Matrix4 matrix) {
  return float64ListToCssTransform(matrix.storage);
}

/// Returns `true` is the [matrix] describes an identity transformation.
bool isIdentityFloat64ListTransform(Float64List matrix) {
  assert(matrix.length == 16);
  final Float64List m = matrix;
  return m[0] == 1.0 &&
      m[1] == 0.0 &&
      m[2] == 0.0 &&
      m[3] == 0.0 &&
      m[4] == 0.0 &&
      m[5] == 1.0 &&
      m[6] == 0.0 &&
      m[7] == 0.0 &&
      m[8] == 0.0 &&
      m[9] == 0.0 &&
      m[10] == 1.0 &&
      m[11] == 0.0 &&
      m[12] == 0.0 &&
      m[13] == 0.0 &&
      m[14] == 0.0 &&
      m[15] == 1.0;
}

/// Converts [matrix] to CSS transform value.
String float64ListToCssTransform(Float64List matrix) {
  assert(matrix.length == 16);
  final Float64List m = matrix;
  if (m[0] == 0.0 &&
      m[1] == 0.0 &&
      m[2] == 0.0 &&
      m[3] == 0.0 &&
      m[4] == 0.0 &&
      m[5] == 0.0 &&
      m[6] == 0.0 &&
      m[7] == 0.0 &&
      m[8] == 0.0 &&
      m[9] == 0.0 &&
      m[10] == 1.0 &&
      m[11] == 0.0 &&
      m[15] == 1.0) {
    var tx = m[12];
    var ty = m[13];
    return 'translate($tx, $ty)';
  } else {
    return 'matrix3d(${m[0]},${m[1]},${m[2]},${m[3]},${m[4]},${m[5]},${m[6]},${m[7]},${m[8]},${m[9]},${m[10]},${m[11]},${m[12]},${m[13]},${m[14]},${m[15]})';
  }
}

bool get assertionsEnabled {
  var k = false;
  assert(k = true);
  return k;
}
