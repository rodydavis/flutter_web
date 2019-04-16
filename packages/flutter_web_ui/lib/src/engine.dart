// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library engine;

import '../ui.dart' as ui;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:collection';
import 'dart:convert' hide Codec;
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

part 'assets/assets.dart';

part 'browser_routing/history.dart';

part 'compositor/engine_delegate.dart';
part 'compositor/layer.dart';
part 'compositor/layer_scene_builder.dart';
part 'compositor/layer_tree.dart';
part 'compositor/raster_cache.dart';
part 'compositor/rasterizer.dart';
part 'compositor/runtime_delegate.dart';
part 'compositor/surface.dart';
part 'compositor/viewport_metrics.dart';
part 'compositor/platform_message.dart';

part 'dom_renderer/dom_renderer.dart';

part 'semantics/checkable.dart';
part 'semantics/incrementable.dart';
part 'semantics/label_and_value.dart';
part 'semantics/scrollable.dart';
part 'semantics/semantics.dart';
part 'semantics/tappable.dart';
part 'semantics/text_field.dart';

part 'services/message_codec.dart';
part 'services/message_codecs.dart';

part 'text/font_collection.dart';
part 'text/measurement.dart';
part 'text/ruler.dart';
part 'text/unicode_range.dart';
part 'text/word_break_properties.dart';
part 'text/word_breaker.dart';

part 'alarm_clock.dart';
part 'dom_renderer.dart';
part 'keyboard.dart';
part 'bitmap_canvas.dart';
part 'util.dart';
part 'validators.dart';
part 'shadow.dart';
part 'recording_canvas.dart';
part 'onscreen_logging.dart';
part 'text_editing.dart';
part 'engine_canvas.dart';
part 'html_image_codec.dart';
part 'dom_canvas.dart';
part 'conic.dart';
part 'browser_detection.dart';
part 'houdini_canvas.dart';
part 'path_to_svg.dart';
part 'vector_math.dart';

bool _engineInitialized = false;

final List<ui.VoidCallback> _hotRestartListeners = <ui.VoidCallback>[];

/// Requests that [listener] is called just before hot restarting the app.
void registerHotRestartListener(ui.VoidCallback listener) {
  _hotRestartListeners.add(listener);
}

/// This method performs one-time initialization of the Web environment that
/// supports the Flutter framework.
///
/// This is only available on the Web, as native Flutter configures the
/// environment in the native embedder.
// TODO(yjbanov): we should refactor the code such that the framework does not
//                call this method directly.
void webOnlyInitializeEngine() {
  if (_engineInitialized) {
    return;
  }

  // Called by the Web runtime just before hot restarting the app.
  //
  // This extension cleans up resources that are registered with browser's
  // global singletons that Dart compiler is unable to clean-up automatically.
  //
  // This extension does not need to clean-up Dart statics. Those are cleaned
  // up by the compiler.
  developer.registerExtension('ext.flutter.disassemble', (_, __) {
    for (ui.VoidCallback listener in _hotRestartListeners) {
      listener();
    }
    return Future.value(developer.ServiceExtensionResponse.result('OK'));
  });

  _engineInitialized = true;

  // Calling this getter to force the DOM renderer to initialize before we
  // initialize framework bindings.
  domRenderer;

  bool waitingForAnimation = false;
  ui.window.webOnlyScheduleFrameCallback = () {
    // We're asked to schedule a frame and call `frameHandler` when the frame
    // fires.
    if (!waitingForAnimation) {
      waitingForAnimation = true;
      html.window.requestAnimationFrame((num highResTime) {
        // Reset immediately, because `frameHandler` can schedule more frames.
        waitingForAnimation = false;

        // We have to convert high-resolution time to `int` so we can construct
        // a `Duration` out of it. However, high-res time is supplied in
        // milliseconds as a double value, with sub-millisecond information
        // hidden in the fraction. So we first multiply it by 1000 to uncover
        // microsecond precision, and only then convert to `int`.
        final highResTimeMicroseconds = (1000 * highResTime).toInt();

        if (ui.window.onBeginFrame != null) {
          ui.window.onBeginFrame(
              new Duration(microseconds: highResTimeMicroseconds));
        }

        if (ui.window.onDrawFrame != null) {
          // TODO(yjbanov): technically Flutter flushes microtasks between
          //                onBeginFrame and onDrawFrame. We don't, which hasn't
          //                been an issue yet, but eventually we'll have to
          //                implement it properly.
          ui.window.onDrawFrame();
        }
      });
    }
  };

  ui.PointerBinding();
  Keyboard.initialize();
}
