// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

Element _logElement;
Element _logContainer;
final StringBuffer _logBuffer = StringBuffer();

int _lineNumber = 1;

/// A drop-in replacement for [print] that prints on the screen into a
/// fixed-positioned element.
///
/// This is useful, for example, for print-debugging on iOS when debugging over
/// USB is not available.
void printOnScreen(Object object) {
  if (_logElement == null) {
    _initialize();
  }

  _logBuffer.writeln('${_lineNumber++}: ${object}');
  _logContainer.text = _logBuffer.toString();
}

void _initialize() {
  _logElement = Element.tag('flt-onscreen-log');
  _logElement.style
    ..position = 'fixed'
    ..left = '0'
    ..right = '0'
    ..bottom = '0'
    ..height = '25%'
    ..backgroundColor = 'rgba(0, 0, 0, 0.85)'
    ..color = 'white'
    ..fontSize = '8px'
    ..whiteSpace = 'pre-wrap'
    ..overflow = 'hidden';

  _logContainer = Element.tag('flt-log-container');
  _logContainer.style
    ..position = 'absolute'
    ..bottom = '0';
  _logElement.append(_logContainer);

  document.body.append(_logElement);
}
