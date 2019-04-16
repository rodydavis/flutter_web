// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This library defines the web equivalent of the native dart:ui.
///
/// All types in this library are public.
library ui;

import 'dart:async';
import 'dart:convert' hide Codec;
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'src/engine.dart' as engine;

import 'package:meta/meta.dart';

export 'src/engine.dart' show webOnlyInitializeEngine;

part 'src/canvas.dart';
part 'src/compositing.dart';
part 'src/geometry.dart';
part 'src/hash_codes.dart';
part 'src/initialization.dart';
part 'src/lerp.dart';
part 'src/natives.dart';
part 'src/painting.dart';
part 'src/pointer.dart';
part 'src/pointer_binding.dart';
part 'src/semantics.dart';
part 'src/browser_routing/strategies.dart';
part 'src/text.dart';
part 'src/tile_mode.dart';
part 'src/window.dart';

/// Provides a compile time constant to customize flutter framework and other
/// users of ui engine for web runtime.
const bool isWeb = true;

/// Web specific SMI. Used by bitfield. The 0x3FFFFFFFFFFFFFFF used on VM
/// is not supported on Web platform.
const int kMaxUnsignedSMI = -1;
