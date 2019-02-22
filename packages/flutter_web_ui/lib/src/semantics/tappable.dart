// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import '../../ui.dart' as ui;

import 'semantics.dart';

/// Listens to HTML "click" gestures detected by the browser.
///
/// This gestures is different from the click and tap gestures detected by the
/// framework from raw pointer events. When an assistive technology is enabled
/// the browser may not send us pointer events. In that mode we forward HTML
/// click as [ui.SemanticsAction.tap].
class Tappable extends RoleManager {
  Tappable(SemanticsObject semanticsObject)
      : super(Role.tappable, semanticsObject);

  html.EventListener _clickListener;

  /// Updates the DOM [_element] based on the current state of the
  /// [semanticsObject] and current gesture mode.
  void update() {
    final html.Element element = semanticsObject.element;

    semanticsObject.setAriaRole(
        'button', semanticsObject.hasFlag(ui.SemanticsFlag.isButton));

    if (semanticsObject.hasAction(ui.SemanticsAction.tap)) {
      if (_clickListener == null) {
        _clickListener = (_) {
          if (semanticsObject.owner.gestureMode !=
              GestureMode.browserGestures) {
            return;
          }
          ui.window.onSemanticsAction(
              semanticsObject.id, ui.SemanticsAction.tap, null);
        };
        element.addEventListener('click', _clickListener);
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    if (_clickListener == null) {
      return;
    }

    semanticsObject.element.removeEventListener('click', _clickListener);
    _clickListener = null;
  }

  /// Cleans up the DOM.
  ///
  /// This object is not usable after calling this method.
  void dispose() {
    _stopListening();
    semanticsObject.setAriaRole('button', false);
  }
}
