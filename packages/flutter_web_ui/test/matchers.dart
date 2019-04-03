// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Provides utilities for testing engine code.
library matchers;

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'package:flutter_web_ui/ui.dart';

/// Enumerates all persisted surfaces in the tree rooted at [root].
///
/// If [root] is `null` returns all surfaces from the last rendered scene.
///
/// Surfaces are returned in a depth-first order.
Iterable<PersistedSurface> enumerateSurfaces([PersistedSurface root]) {
  root ??= SceneBuilder.debugLastFrameScene;
  final List<PersistedSurface> surfaces = <PersistedSurface>[root];

  root.visitChildren((PersistedSurface surface) {
    surfaces.addAll(enumerateSurfaces(surface));
  });

  return surfaces;
}

/// Enumerates all pictures nested under [root].
///
/// If [root] is `null` returns all pictures from the last rendered scene.
Iterable<PersistedPicture> enumeratePictures([PersistedSurface root]) {
  root ??= SceneBuilder.debugLastFrameScene;
  return enumerateSurfaces(root).whereType<PersistedPicture>();
}

/// Computes the distance between two values.
///
/// The distance should be a metric in a metric space (see
/// https://en.wikipedia.org/wiki/Metric_space). Specifically, if `f` is a
/// distance function then the following conditions should hold:
///
/// - f(a, b) >= 0
/// - f(a, b) == 0 if and only if a == b
/// - f(a, b) == f(b, a)
/// - f(a, c) <= f(a, b) + f(b, c), known as triangle inequality
///
/// This makes it useful for comparing numbers, [Color]s, [Offset]s and other
/// sets of value for which a metric space is defined.
typedef DistanceFunction<T> = num Function(T a, T b);

/// The type of a union of instances of [DistanceFunction<T>] for various types
/// T.
///
/// This type is used to describe a collection of [DistanceFunction<T>]
/// functions which have (potentially) unrelated argument types. Since the
/// argument types of the functions may be unrelated, the only thing that the
/// type system can statically assume about them is that they accept null (since
/// all types in Dart are nullable).
///
/// Calling an instance of this type must either be done dynamically, or by
/// first casting it to a [DistanceFunction<T>] for some concrete T.
typedef AnyDistanceFunction = num Function(Null a, Null b);

const Map<Type, AnyDistanceFunction> _kStandardDistanceFunctions =
    <Type, AnyDistanceFunction>{
  Color: _maxComponentColorDistance,
  Offset: _offsetDistance,
  int: _intDistance,
  double: _doubleDistance,
  Rect: _rectDistance,
  Size: _sizeDistance,
};

int _intDistance(int a, int b) => (b - a).abs();
double _doubleDistance(double a, double b) => (b - a).abs();
double _offsetDistance(Offset a, Offset b) => (b - a).distance;

double _maxComponentColorDistance(Color a, Color b) {
  int delta = math.max<int>((a.red - b.red).abs(), (a.green - b.green).abs());
  delta = math.max<int>(delta, (a.blue - b.blue).abs());
  delta = math.max<int>(delta, (a.alpha - b.alpha).abs());
  return delta.toDouble();
}

double _rectDistance(Rect a, Rect b) {
  double delta =
      math.max<double>((a.left - b.left).abs(), (a.top - b.top).abs());
  delta = math.max<double>(delta, (a.right - b.right).abs());
  delta = math.max<double>(delta, (a.bottom - b.bottom).abs());
  return delta;
}

double _sizeDistance(Size a, Size b) {
  final Offset delta = b - a;
  return delta.distance;
}

/// Asserts that two values are within a certain distance from each other.
///
/// The distance is computed by a [DistanceFunction].
///
/// If `distanceFunction` is null, a standard distance function is used for the
/// `runtimeType` of the `from` argument. Standard functions are defined for
/// the following types:
///
///  * [Color], whose distance is the maximum component-wise delta.
///  * [Offset], whose distance is the Euclidean distance computed using the
///    method [Offset.distance].
///  * [Rect], whose distance is the maximum component-wise delta.
///  * [Size], whose distance is the [Offset.distance] of the offset computed as
///    the difference between two sizes.
///  * [int], whose distance is the absolute difference between two integers.
///  * [double], whose distance is the absolute difference between two doubles.
///
/// See also:
///
///  * [moreOrLessEquals], which is similar to this function, but specializes in
///    [double]s and has an optional `epsilon` parameter.
///  * [closeTo], which specializes in numbers only.
Matcher within<T>({
  @required num distance,
  @required T from,
  DistanceFunction<T> distanceFunction,
}) {
  distanceFunction ??= _kStandardDistanceFunctions[from.runtimeType];

  if (distanceFunction == null) {
    throw ArgumentError(
        'The specified distanceFunction was null, and a standard distance '
        'function was not found for type ${from.runtimeType} of the provided '
        '`from` argument.');
  }

  return _IsWithinDistance<T>(distanceFunction, from, distance);
}

class _IsWithinDistance<T> extends Matcher {
  const _IsWithinDistance(this.distanceFunction, this.value, this.epsilon);

  final DistanceFunction<T> distanceFunction;
  final T value;
  final num epsilon;

  @override
  bool matches(Object object, Map<dynamic, dynamic> matchState) {
    if (object is! T) return false;
    if (object == value) return true;
    final T test = object;
    final num distance = distanceFunction(test, value);
    if (distance < 0) {
      throw ArgumentError(
          'Invalid distance function was used to compare a ${value.runtimeType} '
          'to a ${object.runtimeType}. The function must return a non-negative '
          'double value, but it returned $distance.');
    }
    matchState['distance'] = distance;
    return distance <= epsilon;
  }

  @override
  Description describe(Description description) =>
      description.add('$value (±$epsilon)');

  @override
  Description describeMismatch(
    Object object,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    mismatchDescription
        .add('was ${matchState['distance']} away from the desired value.');
    return mismatchDescription;
  }
}
