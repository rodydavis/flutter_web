// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer' as developer;
import 'dart:html' as html;

import 'dom_renderer.dart';
import 'keyboard.dart';
import 'pointer_binding.dart';
import 'window.dart';

bool _engineInitialized = false;

final List<VoidCallback> _hotRestartListeners = <VoidCallback>[];

/// Requests that [listener] is called just before hot restarting the app.
void registerHotRestartListener(VoidCallback listener) {
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
    for (VoidCallback listener in _hotRestartListeners) {
      listener();
    }
    return Future.value(developer.ServiceExtensionResponse.result('OK'));
  });

  _engineInitialized = true;

  // Calling this getter to force the DOM renderer to initialize before we
  // initialize framework bindings.
  domRenderer;

  bool waitingForAnimation = false;
  window.webOnlyScheduleFrameCallback = () {
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

        if (window.onBeginFrame != null) {
          window.onBeginFrame(
              new Duration(microseconds: highResTimeMicroseconds));
        }

        if (window.onDrawFrame != null) {
          // TODO(yjbanov): technically Flutter flushes microtasks between
          //                onBeginFrame and onDrawFrame. We don't, which hasn't
          //                been an issue yet, but eventually we'll have to
          //                implement it properly.
          window.onDrawFrame();
        }
      });
    }
  };

  PointerBinding();
  Keyboard.initialize();
}
