// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_web_ui/ui.dart' as ui;

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

/// Should be used as a singleton to provide support for text editing in
/// Flutter Web.
///
/// The approach is "hybrid" because it relies on Flutter for
/// displaying, and HTML for user interactions:
///
/// - HTML's contentEditable feature handles typing and text changes.
/// - HTML's selection API handles selection changes and cursor movements.
class HybridTextEditing {
  HtmlElement _element;

  /// Lazily create an editable element and cache it.
  HtmlElement get element {
    if (_element == null) {
      _element = _createEditable();
    }
    return _element;
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
        _startEditing(_lastEditingState);
        break;

      case 'TextInput.clearClient':
        _stopEditing();
        break;
    }
  }

  void _startEditing(Map<String, dynamic> editingState) {
    _isEditing = true;
    _syncEditingStateToElement(editingState);

    // Subscribe to text and selection changes.
    _subscriptions
      // This prevents the content editable span from losing focus. The only way
      // to lose focus is when Flutter sends a `TextInput.clearClient` message.
      ..add(element.onBlur.listen((_) => element.focus()))
      ..add(document.onSelectionChange
          .listen((_) => _syncEditingStateToFlutter()))
      ..add(element.onInput.listen((_) => _syncEditingStateToFlutter()));
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
  }

  void _stopEditing() {
    _isEditing = true;
    _lastEditingState = null;
    for (int i = 0; i < _subscriptions.length; i++) {
      _subscriptions[i].cancel();
    }
    _subscriptions.clear();
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
      print('newSelExtent: $newSelectionExtent');
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
