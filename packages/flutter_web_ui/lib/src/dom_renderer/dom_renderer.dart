// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html
    show
        CssStyleSheet,
        DivElement,
        document,
        Element,
        MetaElement,
        StyleElement,
        Node,
        window;
import 'dart:js_util' as js_util;

import 'package:flutter_web_ui/ui.dart' as ui;

import '../text/measurement.dart';
import '../util.dart';

class DomRenderer {
  DomRenderer() {
    if (assertionsEnabled) {
      _debugFrameStatistics = DebugDomRendererFrameStatistics();
    }

    reset();

    TextMeasurementService.initialize(rulerCacheCapacity: 10);
  }

  static const int vibrateLongPress = 50;
  static const int vibrateLightImpact = 10;
  static const int vibrateMediumImpact = 20;
  static const int vibrateHeavyImpact = 30;
  static const int vibrateSelectionClick = 10;

  bool get debugIsInWidgetTest => _debugIsInWidgetTest;
  set debugIsInWidgetTest(bool value) {
    _debugIsInWidgetTest = value;
    if (_debugIsInWidgetTest) {
      var logicalSize = ui.Size(800.0, 600.0);
      ui.window.physicalSize = logicalSize * ui.window.devicePixelRatio;
    }
  }

  bool _debugIsInWidgetTest = false;

  final html.Element rootElement = html.document.body;

  void addElementClass(html.Element element, String className) {
    element.classes.add(className);
  }

  void attachBeforeElement(
      html.Element parent, html.Element before, html.Element newElement) {
    assert(parent != null);
    if (parent != null) {
      assert(() {
        if (before == null) {
          return true;
        }
        if (before.parent != parent) {
          throw Exception(
            'attachBeforeElement was called with `before` element that\'s '
                'not a child of the `parent` element:\n'
                '  before: $before\n'
                '  parent: $parent',
          );
        }
        return true;
      }());
      parent.insertBefore(newElement, before);
    }
  }

  html.Element createElement(String tagName, {html.Element parent}) {
    html.Element element = html.document.createElement(tagName);
    parent?.append(element);
    return element;
  }

  void append(html.Element parent, html.Element child) {
    parent.append(child);
  }

  void appendText(html.Element parent, String text) {
    parent.appendText(text);
  }

  void detachElement(html.Element element) {
    element.remove();
  }

  void removeElementClass(html.Element element, String className) {
    element.classes.remove(className);
  }

  void setElementAttribute(html.Element element, String name, String value) {
    element.setAttribute(name, value);
  }

  void setElementProperty(html.Element element, String name, Object value) {
    js_util.setProperty(element, name, value);
  }

  void setElementStyle(html.Element element, String name, String value) {
    if (value == null) {
      element.style.removeProperty(name);
    } else {
      element.style.setProperty(name, value);
    }
  }

  void setText(html.Element element, String text) {
    element.text = text;
  }

  void removeAllChildren(html.Element element) {
    element.children.clear();
  }

  html.Element getParent(html.Element element) => element.parent;

  void setTitle(String title) {
    html.document.title = title;
  }

  void setThemeColor(ui.Color color) {
    html.MetaElement theme = html.document.querySelector('#flutterweb-theme');
    if (theme == null) {
      theme = new html.MetaElement()
        ..id = 'flutterweb-theme'
        ..name = 'theme-color';
      html.document.head.append(theme);
    }
    theme.content = color.toCssString();
  }

  static const String defaultFontStyle = 'normal';
  static const String defaultFontWeight = 'normal';
  static const String defaultFontSize = '14px';
  static const String defaultFontFamily = 'sans-serif';
  static const String defaultCssFont =
      '$defaultFontStyle $defaultFontWeight $defaultFontSize $defaultFontFamily';

  void reset() {
    html.StyleElement styleElement = new html.StyleElement();
    html.document.head.append(styleElement);
    html.CssStyleSheet sheet = styleElement.sheet;

    // TODO(butterfly): use more efficient CSS selectors; descendant selectors
    //                  are slow. More info:
    //
    //                  https://csswizardry.com/2011/09/writing-efficient-css-selectors/

    // This undoes browser's default layout attributes for paragraphs. We
    // compute paragraph layout ourselves.
    sheet.insertRule('''
flt-ruler-host p, flt-scene p {
  margin: 0;
}''', sheet.cssRules.length);

    // This undoes browser's default painting and layout attributes of range
    // input, which is used in semantics.
    sheet.insertRule('''
flt-semantics input[type=range] {
  appearance: none;
  -webkit-appearance: none;
  width: 100%;
  position: absolute;
  border: none;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
}''', sheet.cssRules.length);

    sheet.insertRule('''
flt-semantics input[type=range]::-webkit-slider-thumb {
  -webkit-appearance: none;
}
''', sheet.cssRules.length);

    final bodyElement = html.document.body;
    setElementStyle(bodyElement, 'position', 'fixed');
    setElementStyle(bodyElement, 'top', '0');
    setElementStyle(bodyElement, 'right', '0');
    setElementStyle(bodyElement, 'bottom', '0');
    setElementStyle(bodyElement, 'left', '0');
    setElementStyle(bodyElement, 'overflow', 'hidden');
    setElementStyle(bodyElement, 'padding', '0');
    setElementStyle(bodyElement, 'margin', '0');

    // TODO(yjbanov): fix this when we support KVM I/O. Currently we scroll
    //                using drag, and text selection interferes.
    setElementStyle(bodyElement, 'user-select', 'none');
    setElementStyle(bodyElement, '-webkit-user-select', 'none');
    setElementStyle(bodyElement, '-ms-user-select', 'none');
    setElementStyle(bodyElement, '-moz-user-select', 'none');

    // This is required to prevent the browser from doing any native touch
    // handling. If we don't do this, the browser doesn't report 'pointermove'
    // events properly.
    setElementStyle(bodyElement, 'touch-action', 'none');

    // These are intentionally outrageous font parameters to make sure that the
    // apps fully specifies their text styles.
    setElementStyle(bodyElement, 'font', defaultCssFont);
    setElementStyle(bodyElement, 'color', 'red');

    for (html.Element viewportMeta
        in html.document.head.querySelectorAll('meta[name="viewport"]')) {
      if (assertionsEnabled) {
        print(
          'WARNING: found an existing <meta name="viewport"> tag. Flutter Web '
              'uses its own viewport configuration for better compatibility '
              'with Flutter. This tag will be replaced.',
        );
      }
      viewportMeta.remove();
    }

    html.MetaElement viewportMeta = html.MetaElement()
      ..name = 'viewport'
      ..content = 'width=device-width, initial-scale=1.0, '
          'maximum-scale=1.0, user-scalable=no';
    html.document.head.append(viewportMeta);

    // We treat browser pixels as device pixels because pointer events,
    // position, and sizes all use browser pixel as the unit (i.e. "px" in CSS).
    // Therefore, as far as the framework is concerned the device pixel ratio
    // is 1.0.
    ui.window.devicePixelRatio = 1.0;

    var logicalSize = new ui.Size(
      html.window.innerWidth.toDouble(),
      html.window.innerHeight.toDouble(),
    );
    ui.window.physicalSize = logicalSize * ui.window.devicePixelRatio;

    // TODO: handle removing listener once we have app destroy lifecycle.
    html.window.onResize.listen((_) {
      var logicalSize = new ui.Size(
        html.window.innerWidth.toDouble(),
        html.window.innerHeight.toDouble(),
      );
      ui.window.physicalSize = logicalSize * ui.window.devicePixelRatio;
      if (ui.window.onMetricsChanged != null) {
        ui.window.onMetricsChanged();
      }
    });
  }

  void focus(html.Element element) {
    element.focus();
  }

  /// Removes all children of a DOM node.
  void clearDom(html.Node node) {
    while (node.lastChild != null) {
      node.lastChild.remove();
    }
  }

  /// The element corresponding to the only child of the root surface.
  html.Element get _rootApplicationElement {
    return (rootElement.children.last as html.DivElement).children.singleWhere(
        (html.Element element) {
      return element.tagName == 'FLT-SCENE';
    }, orElse: () => null);
  }

  /// Provides haptic feedback.
  Future vibrate(int durationMs) {
    var navigator = html.window.navigator;
    if (js_util.hasProperty(navigator, 'vibrate')) {
      js_util.callMethod(navigator, 'vibrate', <num>[durationMs]);
    }
    return null;
  }

  String get currentHtml => _rootApplicationElement?.outerHtml ?? '';

  DebugDomRendererFrameStatistics _debugFrameStatistics;

  DebugDomRendererFrameStatistics debugFlushFrameStatistics() {
    if (!assertionsEnabled) {
      throw Exception('This code should not be reachable in production.');
    }
    var current = _debugFrameStatistics;
    _debugFrameStatistics = DebugDomRendererFrameStatistics();
    return current;
  }

  void debugRulerCacheHit() => _debugFrameStatistics.paragraphRulerCacheHits++;
  void debugRulerCacheMiss() =>
      _debugFrameStatistics.paragraphRulerCacheMisses++;
  void debugRichTextLayout() => _debugFrameStatistics.richTextLayouts++;
  void debugPlainTextLayout() => _debugFrameStatistics.plainTextLayouts++;
}

/// Miscellaneous statistics collecting during a single frame's execution.
///
/// This is useful when profiling the app. This class should only be used when
/// assertions are enabled and therefore is not suitable for collecting any
/// time measurements. It is mostly useful for counting certain events.
class DebugDomRendererFrameStatistics {
  /// The number of times we reused a previously initialized paragraph ruler to
  /// measure a paragraph of text.
  int paragraphRulerCacheHits = 0;

  /// The number of times we had to create a new paragraph ruler to measure a
  /// paragraph of text.
  int paragraphRulerCacheMisses = 0;

  /// The number of times we used a paragraph ruler to measure a paragraph of
  /// text.
  int get totalParagraphRulerAccesses =>
      paragraphRulerCacheHits + paragraphRulerCacheMisses;

  /// The number of times a paragraph of rich text was laid out this frame.
  int richTextLayouts = 0;

  /// The number of times a paragraph of plain text was laid out this frame.
  int plainTextLayouts = 0;

  @override
  String toString() {
    return '''
Frame statistics:
  Paragraph ruler cache hits: ${paragraphRulerCacheHits}
  Paragraph ruler cache misses: ${paragraphRulerCacheMisses}
  Paragraph ruler accesses: ${totalParagraphRulerAccesses}
  Rich text layouts: ${richTextLayouts}
  Plain text layouts: ${plainTextLayouts}
'''
        .trim();
  }
}

// TODO(yjbanov): Replace this with an explicit initialization function. The
//                lazy initialization of statics makes it very unpredictable, as
//                the constructor has side-effects.
/// Singleton DOM renderer.
final DomRenderer domRenderer = DomRenderer();
