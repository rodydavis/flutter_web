// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

html.Element _logElement;
html.Element _logContainer;
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

  final String message = '${_lineNumber++}: ${object}';
  _logBuffer.writeln(message);
  _logContainer.text = _logBuffer.toString();

  // Also log to console for browsers that give you access to it.
  print(message);
}

void _initialize() {
  _logElement = html.Element.tag('flt-onscreen-log');
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
    ..overflow = 'hidden'
    ..zIndex = '1000';

  _logContainer = html.Element.tag('flt-log-container');
  _logContainer.style
    ..position = 'absolute'
    ..bottom = '0';
  _logElement.append(_logContainer);

  html.document.body.append(_logElement);
}
