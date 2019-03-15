// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_web_ui/ui.dart' as ui;

import 'browser_detection.dart';
import 'dom_renderer.dart';
import 'services.dart';

/// Make the content editable span visible to facilitate debugging.
const _debugVisibleTextEditing = false;

void _emptyCallback(_) {}

HtmlElement _createEditable() {
  final HtmlElement element = SpanElement();
  element.id = 'textediting';
  element.contentEditable = 'plaintext-only';
  element.style
    ..position = 'fixed'
    // We only support single-line editing now. `pre` prevents text wrapping.
    ..whiteSpace = 'pre';

  if (_debugVisibleTextEditing) {
    element.style
      ..bottom = '0'
      ..right = '0'
      ..font = '24px sans-serif'
      ..color = 'purple'
      ..backgroundColor = 'pink';
  } else {
    element.style
      ..overflow = 'hidden'
      ..transform = 'translate(-99999px, -99999px)'
      // width and height can't be zero because then the element would stop
      // receiving edits when its content is empty.
      ..width = '1px'
      ..height = '1px';
  }
  document.body.append(element);
  return element;
}

/// Text editing singleton.
final HybridTextEditing textEditing = HybridTextEditing();

/// Should be used as a singleton to provide support for text editing in
/// Flutter Web.
///
/// The approach is "hybrid" because it relies on Flutter for
/// displaying, and HTML for user interactions:
///
/// - HTML's contentEditable feature handles typing and text changes.
/// - HTML's selection API handles selection changes and cursor movements.
class HybridTextEditing {
  /// The default HTML element used to manage editing state when a custom
  /// element is not provided via [useCustomEditableElement].
  HtmlElement _defaultEditableElement;

  /// The HTML element used to manage editing state.
  ///
  /// This field is populated using [useCustomEditableElement]. If `null` the
  /// [_defaultEditableElement] is used instead.
  HtmlElement _customEditableElement;

  /// Returns the HTML element used to manage editing state.
  ///
  /// If a custom element was provided using [useCustomEditableElement], this
  /// method returns it. Otherwise, it lazily creates an editable element,
  /// caches it, and returns it.
  HtmlElement get element {
    if (_customEditableElement != null) {
      return _customEditableElement;
    }
    if (_defaultEditableElement == null) {
      _defaultEditableElement = _createEditable();
    }
    return _defaultEditableElement;
  }

  /// Requests that [customElement] is used for managing text editing state
  /// instead of the hidden default element.
  ///
  /// Use [stopUsingCustomEditableElement] to switch back to default element.
  void useCustomEditableElement(HtmlElement customElement) {
    if (customElement != _customEditableElement) {
      _stopEditing();
    }
    _customEditableElement = customElement;
  }

  /// Switches back to using the built-in default element for managing text
  /// editing state.
  void stopUsingCustomEditableElement() {
    useCustomEditableElement(null);
  }

  int _clientId;
  bool _isEditing = false;
  Map<String, dynamic> _lastEditingState;

  final List<StreamSubscription> _subscriptions = [];

  /// All "flutter/textinput" platform messages should be sent to this method.
  void handleTextInput(ByteData data) {
    final MethodCall call = const JSONMethodCodec().decodeMethodCall(data);
    switch (call.method) {
      case 'TextInput.setClient':
        _clientId = call.arguments[0];
        break;

      case 'TextInput.setEditingState':
        _lastEditingState = call.arguments;
        if (_isEditing) {
          _syncEditingStateToElement(_lastEditingState);
        }
        break;

      case 'TextInput.show':
        if (!_isEditing) {
          _startEditing(_lastEditingState);
        }
        break;

      case 'TextInput.clearClient':
      case 'TextInput.hide':
        if (_isEditing) {
          _stopEditing();
        }
        break;
    }
  }

  void _startEditing(Map<String, dynamic> editingState) {
    _isEditing = true;
    _syncEditingStateToElement(editingState);

    // Chrome on Android will hide the onscreen keyboard when you tap outside
    // the text box. Instead, we want the framework to tell us to hide the
    // keyboard via `TextInput.clearClient` or `TextInput.hide`.
    //
    // Safari on iOS does not hide the keyboard as a side-effect of tapping
    // outside the editable box. Instead it provides an explicit "done" button,
    // which is reported as "blur", so we must not reacquire focus when we see
    // a "blur" event and let the keyboard disappear.
    if (browserEngine == BrowserEngine.blink ||
        browserEngine == BrowserEngine.unknown) {
      _subscriptions.add(element.onBlur.listen((_) {
        element.focus();
      }));
    }

    // Subscribe to text and selection changes.
    _subscriptions
      ..add(document.onSelectionChange.listen((_) {
        _syncEditingStateToFlutter();
      }))
      ..add(element.onInput.listen((_) {
        _syncEditingStateToFlutter();
      }));
  }

  /// Takes the [editingState] sent from Flutter's [TextInputConnection] and
  /// applies it to the contentEditable element.
  void _syncEditingStateToElement(Map<String, dynamic> editingState) {
    // The `editingState` map has the following structure:
    // {
    //   text: "The text here",
    //   selectionBase: 0,
    //   selectionExtent: 0,
    //   selectionAffinity: "TextAffinity.upstream",
    //   selectionIsDirectional: false,
    //   composingBase: -1,
    //   composingExtent: -1
    // }
    if (!_isValidSelection(editingState)) {
      return;
    }

    domRenderer.clearDom(element);
    element.append(Text(editingState['text']));
    window.getSelection()
      ..removeAllRanges()
      ..addRange(_createRange(editingState));

    // Safari on iOS requires that we focus explicitly. Otherwise, the on-screen
    // keyboard won't show up.
    element.focus();
  }

  void _stopEditing() {
    _isEditing = false;
    _lastEditingState = null;
    for (int i = 0; i < _subscriptions.length; i++) {
      _subscriptions[i].cancel();
    }
    _subscriptions.clear();

    // Remove focus from the editable element to cause the keyboard to hide.
    // Otherwise, the keyboard stays on screen even when the user navigates to
    // a different screen (e.g. by hitting the "back" button).
    element.blur();
  }

  /// Reads the current editing state of the content editable element and sends
  /// it to Flutter's [TextInputConnection].
  void _syncEditingStateToFlutter() {
    assert(_lastEditingState != null);

    _calculateCurrentEditingState(_lastEditingState);

    ui.window.onPlatformMessage(
      'flutter/textinput',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('TextInputClient.updateEditingState', [
          _clientId,
          _lastEditingState,
        ]),
      ),
      _emptyCallback,
    );
  }

  void _calculateCurrentEditingState(Map<String, dynamic> editingState) {
    final String text = element.text;
    if (element.childNodes.length > 1) {
      // Having multiple child nodes in a content editable elements means one of
      // two things:
      // 1. Text contains new lines.
      // 2. User pasted rich text.
      final int prevSelectionEnd = math.max(
        editingState['selectionBase'],
        editingState['selectionExtent'],
      );
      final String prevText = editingState['text'];
      final int offsetFromEnd = prevText.length - prevSelectionEnd;
      // Remove any new lines.
      final String newText = text.replaceAll('\n', '');
      final int newSelectionExtent = newText.length - offsetFromEnd;
      editingState
        ..['text'] = newText
        ..['selectionBase'] = newSelectionExtent
        ..['selectionExtent'] = newSelectionExtent;
      _syncEditingStateToElement(editingState);
    } else {
      final Selection selection = window.getSelection();
      editingState
        ..['text'] = element.text
        ..['selectionBase'] = selection.baseOffset
        ..['selectionExtent'] = selection.extentOffset;
    }
  }

  Range _createRange(Map<String, dynamic> editingState) {
    final Range range = document.createRange();
    final Node firstChild = element.firstChild;
    range
      ..setStart(firstChild, editingState['selectionBase'])
      ..setEnd(firstChild, editingState['selectionExtent']);
    return range;
  }

  bool _isValidSelection(Map<String, dynamic> editingState) {
    return editingState['selectionBase'] >= 0 &&
        editingState['selectionExtent'] >= 0;
  }
}
