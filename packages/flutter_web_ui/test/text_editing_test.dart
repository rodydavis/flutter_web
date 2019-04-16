// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';
import 'dart:typed_data';

import 'package:flutter_web_ui/ui.dart' as ui;
import 'package:flutter_web_ui/src/engine.dart'
    show
        MethodCall,
        MethodCodec,
        JSONMethodCodec,
        TextEditingElement,
        EditingState,
        PersistentTextEditingElement,
        HybridTextEditing;
import 'package:flutter_web_test/flutter_web_test.dart';

final MethodCodec codec = JSONMethodCodec();

TextEditingElement editingElement;
EditingState lastEditingState;

void trackEditingState(EditingState editingState) {
  lastEditingState = editingState;
}

void main() {
  group('$TextEditingElement', () {
    setUp(() {
      editingElement = TextEditingElement();
    });

    tearDown(() {
      try {
        editingElement.disable();
      } catch (e) {
        if (e is AssertionError) {
          // This is fine. It just means the test itself disabled the editing element.
        } else {
          rethrow;
        }
      }
    });

    test('Creates element when enabled and removes it when disabled', () {
      expect(
        document.getElementsByTagName('input'),
        hasLength(0),
      );
      // The focus initially is on the body.
      expect(document.activeElement, document.body);

      editingElement.enable(onChange: trackEditingState);
      expect(
        document.getElementsByTagName('input'),
        hasLength(1),
      );
      // Now the editing element should have focus.
      expect(
        document.activeElement,
        document.getElementsByTagName('input')[0],
      );

      editingElement.disable();
      expect(
        document.getElementsByTagName('input'),
        hasLength(0),
      );
      // The focus is back to the body.
      expect(document.activeElement, document.body);
    });

    test('Can read editing state correctly', () {
      editingElement.enable(onChange: trackEditingState);

      final InputElement input = editingElement.domElement;
      input.value = 'foo bar';
      input.dispatchEvent(Event.eventType('Event', 'input'));
      expect(
        lastEditingState,
        EditingState(text: 'foo bar', baseOffset: 7, extentOffset: 7),
      );

      input.setSelectionRange(4, 6);
      document.dispatchEvent(Event.eventType('Event', 'selectionchange'));
      expect(
        lastEditingState,
        EditingState(text: 'foo bar', baseOffset: 4, extentOffset: 6),
      );
    });

    test('Can set editing state correctly', () {
      editingElement.enable(onChange: trackEditingState);
      editingElement.setEditingState(
          EditingState(text: 'foo bar baz', baseOffset: 2, extentOffset: 7));

      checkEditingState(editingElement.domElement, 'foo bar baz', 2, 7);
    });

    test('Re-acquires focus', () async {
      editingElement.enable(onChange: trackEditingState);
      expect(document.activeElement, editingElement.domElement);

      editingElement.domElement.blur();
      // The focus remains on [editingElement.domElement].
      expect(document.activeElement, editingElement.domElement);
    });

    test('Can swap backing elements on the fly', () {
      // TODO(mdebbar): implement.
    });

    group('[persistent mode]', () {
      test('Does not accept dom elements of a wrong type', () {
        // A regular <span> shouldn't be accepted.
        final HtmlElement span = SpanElement();
        expect(
          () => PersistentTextEditingElement(span, onDomElementSwap: null),
          throwsAssertionError,
        );
      });

      test('Does not re-acquire focus', () {
        // See [PersistentTextEditingElement._refocus] for an explanation of why
        // re-acquiring focus shouldn't happen in persistent mode.
        final InputElement input = InputElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(input, onDomElementSwap: () {});
        expect(document.activeElement, document.body);

        document.body.append(input);
        persistentEditingElement.enable(onChange: trackEditingState);
        expect(document.activeElement, input);

        // The input should lose focus now.
        persistentEditingElement.domElement.blur();
        expect(document.activeElement, document.body);

        persistentEditingElement.disable();
      });

      test('Does not dispose and recreate dom elements in persistent mode', () {
        final InputElement input = InputElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(input, onDomElementSwap: () {});

        // The DOM element should've been eagerly created.
        expect(input, isNotNull);
        // But doesn't have focus.
        expect(document.activeElement, document.body);

        // Can't enable before the input element is inserted into the DOM.
        expect(
          () => persistentEditingElement.enable(onChange: trackEditingState),
          throwsAssertionError,
        );

        document.body.append(input);
        persistentEditingElement.enable(onChange: trackEditingState);
        expect(document.activeElement, persistentEditingElement.domElement);
        // It doesn't create a new DOM element.
        expect(persistentEditingElement.domElement, input);

        persistentEditingElement.disable();
        // It doesn't remove the DOM element.
        expect(persistentEditingElement.domElement, input);
        expect(document.body.contains(persistentEditingElement.domElement),
            isTrue);
        // But the DOM element loses focus.
        expect(document.activeElement, document.body);
      });

      test('Refocuses when setting editing state', () {
        final InputElement input = InputElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(input, onDomElementSwap: () {});

        document.body.append(input);
        persistentEditingElement.enable(onChange: trackEditingState);
        expect(document.activeElement, input);

        persistentEditingElement.domElement.blur();
        expect(document.activeElement, document.body);

        // The input should regain focus now.
        persistentEditingElement.setEditingState(EditingState(text: 'foo'));
        expect(document.activeElement, input);

        persistentEditingElement.disable();
      });

      test('Calls setupDomElement and insertDomElement', () {
        final InputElement input = InputElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(input, onDomElementSwap: () {});

        // The DOM element should've been eagerly created.
        expect(input, isNotNull);
        // But doesn't have focus.
        expect(document.activeElement, document.body);

        expect(
          () => persistentEditingElement.enable(onChange: trackEditingState),
          throwsAssertionError,
        );
        document.body.append(persistentEditingElement.domElement);
        persistentEditingElement.enable(onChange: trackEditingState);
        expect(document.activeElement, persistentEditingElement.domElement);
        // It doesn't create a new DOM element.
        expect(persistentEditingElement.domElement, input);

        persistentEditingElement.disable();
        // It doesn't remove the DOM element.
        expect(persistentEditingElement.domElement, input);
        expect(document.body.contains(persistentEditingElement.domElement),
            isTrue);
        // But the DOM element loses focus.
        expect(document.activeElement, document.body);
      });
    });
  });

  group('$HybridTextEditing', () {
    HybridTextEditing textEditing;
    PlatformMessagesSpy spy = PlatformMessagesSpy();

    setUp(() {
      textEditing = HybridTextEditing();
      spy.activate();
    });

    tearDown(() {
      spy.deactivate();
    });

    test('setClient, show, setEditingState, hide', () {
      MethodCall setClient = MethodCall('TextInput.setClient', [123]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      // Editing shouldn't have started yet.
      expect(document.activeElement, document.body);

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      checkEditingState(textEditing.editingElement.domElement, '', 0, 0);

      MethodCall setEditingState = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState));

      checkEditingState(textEditing.editingElement.domElement, 'abcd', 2, 3);

      MethodCall hide = MethodCall('TextInput.hide');
      textEditing.handleTextInput(codec.encodeMethodCall(hide));

      // Text editing should've stopped.
      expect(document.activeElement, document.body);

      // Confirm that [HybridTextEditing] didn't send any messages.
      expect(spy.messages, isEmpty);
    });

    test('setClient, setEditingState, show, clearClient', () {
      MethodCall setClient = MethodCall('TextInput.setClient', [123]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      MethodCall setEditingState = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState));

      // Editing shouldn't have started yet.
      expect(document.activeElement, document.body);

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      checkEditingState(textEditing.editingElement.domElement, 'abcd', 2, 3);

      MethodCall clearClient = MethodCall('TextInput.clearClient');
      textEditing.handleTextInput(codec.encodeMethodCall(clearClient));

      expect(document.activeElement, document.body);

      // Confirm that [HybridTextEditing] didn't send any messages.
      expect(spy.messages, isEmpty);
    });

    test('setClient, setEditingState, show, setEditingState, clearClient', () {
      MethodCall setClient = MethodCall('TextInput.setClient', [123]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      MethodCall setEditingState1 = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState1));

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      MethodCall setEditingState2 = MethodCall('TextInput.setEditingState', {
        'text': 'xyz',
        'selectionBase': 0,
        'selectionExtent': 2,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState2));

      // The second [setEditingState] should override the first one.
      checkEditingState(textEditing.editingElement.domElement, 'xyz', 0, 2);

      MethodCall clearClient = MethodCall('TextInput.clearClient');
      textEditing.handleTextInput(codec.encodeMethodCall(clearClient));

      // Confirm that [HybridTextEditing] didn't send any messages.
      expect(spy.messages, isEmpty);
    });

    test('Syncs the editing state back to Flutter', () {
      MethodCall setClient = MethodCall('TextInput.setClient', [123]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      MethodCall setEditingState = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState));

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      final InputElement input = textEditing.editingElement.domElement;

      input.value = 'something';
      input.dispatchEvent(Event.eventType('Event', 'input'));

      expect(spy.messages, hasLength(1));
      MethodCall call = spy.messages[0];
      spy.messages.clear();
      expect(call.method, 'TextInputClient.updateEditingState');
      expect(
        call.arguments,
        [
          123, // Client ID
          {'text': 'something', 'selectionBase': 9, 'selectionExtent': 9}
        ],
      );

      input.setSelectionRange(2, 5);
      document.dispatchEvent(Event.eventType('Event', 'selectionchange'));

      expect(spy.messages, hasLength(1));
      call = spy.messages[0];
      spy.messages.clear();
      expect(call.method, 'TextInputClient.updateEditingState');
      expect(
        call.arguments,
        [
          123, // Client ID
          {'text': 'something', 'selectionBase': 2, 'selectionExtent': 5}
        ],
      );

      MethodCall clearClient = MethodCall('TextInput.clearClient');
      textEditing.handleTextInput(codec.encodeMethodCall(clearClient));
    });
  });
}

void checkEditingState(InputElement input, String text, int start, int end) {
  expect(document.activeElement, input);
  expect(input.value, text);
  expect(input.selectionStart, start);
  expect(input.selectionEnd, end);
}

class PlatformMessagesSpy {
  bool _isActive = false;
  ui.PlatformMessageCallback _backup;

  final List<MethodCall> messages = [];

  void activate() {
    assert(!_isActive);
    _isActive = true;
    _backup = ui.window.onPlatformMessage;
    ui.window.onPlatformMessage = (String channel, ByteData data,
        ui.PlatformMessageResponseCallback callback) {
      messages.add(codec.decodeMethodCall(data));
    };
  }

  void deactivate() {
    assert(_isActive);
    _isActive = false;
    messages.clear();
    ui.window.onPlatformMessage = _backup;
  }
}
