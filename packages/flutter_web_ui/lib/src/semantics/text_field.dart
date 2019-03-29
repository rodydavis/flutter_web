// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:js_util' as js_util;

import '../../ui.dart' as ui;

import '../browser_detection.dart';
import '../text_editing.dart';

import 'semantics.dart';

/// Manages semantics objects that represent editable text fields.
///
/// This role is implemented via a content-editable HTML element. This role does
/// not proactively switch modes depending on the current
/// [EngineSemanticsOwner.gestureMode]. However, in Chrome on Android it ignores
/// browser gestures when in pointer mode. In Safari on iOS touch events are
/// used to detect text box invocation. This is because Safari issues touch
/// events even when Voiceover is enabled.
class TextField extends RoleManager {
  TextField(SemanticsObject semanticsObject)
      : super(Role.textField, semanticsObject) {
    _textFieldElement.contentEditable = 'plaintext-only';
    _textFieldElement.setAttribute('role', 'textbox');
    _textFieldElement.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..width = '${semanticsObject.rect.width}px'
      ..height = '${semanticsObject.rect.height}px'
      ..userSelect = 'text'
      ..setProperty('-webkit-user-select', 'text');
    js_util.setProperty(_textFieldElement.style, 'caretColor', 'transparent');
    semanticsObject.element.append(_textFieldElement);

    switch (browserEngine) {
      case BrowserEngine.blink:
      case BrowserEngine.unknown:
        _initializeForBlink();
        break;
      case BrowserEngine.webkit:
        _initializeForWebkit();
        break;
    }
  }

  final html.Element _textFieldElement =
      html.Element.tag('flt-semantics-text-field');

  /// Chrome on Android reports text field activation as a "click" event.
  ///
  /// When in browser gesture mode, the click is forwarded to the framework as
  /// a tap to initialize editing.
  void _initializeForBlink() {
    _textFieldElement.addEventListener('click', (_) {
      if (semanticsObject.owner.gestureMode != GestureMode.browserGestures) {
        return;
      }

      // This works around a seemingly buggy behavior in TalkBack. If the
      // element is already focused and the keyboard has never been invoked or
      // has been dismissed, TalkBack will not show the keyboard even when you
      // double-tap to activate. Artificially blurring the element and
      // immediately focusing it bring up the keyboard.
      _textFieldElement.blur();
      _textFieldElement.focus();
      ui.window
          .onSemanticsAction(semanticsObject.id, ui.SemanticsAction.tap, null);
    });
  }

  /// Safari on iOS reports text field activation via touch events.
  ///
  /// This emulates a tap recognizer to detect the activation. Because touch
  /// events are present regardless of whether accessibility is enabled or not,
  /// this mode is always enabled.
  void _initializeForWebkit() {
    num lastTouchStartOffsetX;
    num lastTouchStartOffsetY;

    _textFieldElement.addEventListener('touchstart', (html.Event event) {
      textEditing.useCustomEditableElement(_textFieldElement);
      html.TouchEvent touchEvent = event;
      lastTouchStartOffsetX = touchEvent.changedTouches.last.client.x;
      lastTouchStartOffsetY = touchEvent.changedTouches.last.client.y;
    }, true);

    _textFieldElement.addEventListener('touchend', (html.Event event) {
      html.TouchEvent touchEvent = event;

      if (lastTouchStartOffsetX != null) {
        assert(lastTouchStartOffsetY != null);
        final num offsetX = touchEvent.changedTouches.last.client.x;
        final num offsetY = touchEvent.changedTouches.last.client.y;

        // This should match the similar constant define in:
        //
        // lib/src/gestures/constants.dart
        //
        // The value is pre-squared so we have to do less math at runtime.
        const double kTouchSlop = 18.0 * 18.0; // Logical pixels squared

        if (offsetX * offsetX + offsetY * offsetY < kTouchSlop) {
          // Recognize it as a tap that requires a keyboard.
          ui.window.onSemanticsAction(
              semanticsObject.id, ui.SemanticsAction.tap, null);
        }
      } else {
        assert(lastTouchStartOffsetY == null);
      }

      lastTouchStartOffsetX = null;
      lastTouchStartOffsetY = null;
    }, true);
  }

  @override
  void update() {
    // TODO(yjbanov): This interferes with the editing state because it resets
    // the selection state in [_textFieldElement].
    if (semanticsObject.owner.gestureMode == GestureMode.browserGestures &&
        browserEngine != BrowserEngine.webkit) {
      _textFieldElement.text = semanticsObject.value ?? '';
    }
  }

  @override
  void dispose() {
    _textFieldElement.remove();
    semanticsObject.setAriaRole('textbox', false);
    textEditing.stopUsingCustomEditableElement();
  }
}
