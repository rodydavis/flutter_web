// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// Contains the subset of [ui.ParagraphStyle] properties that affect layout.
class ParagraphGeometricStyle {
  ParagraphGeometricStyle({
    this.fontWeight,
    this.fontStyle,
    this.fontFamily,
    this.fontSize,
    this.lineHeight,
    this.letterSpacing,
    this.wordSpacing,
    this.decoration,
  });

  final ui.FontWeight fontWeight;
  final ui.FontStyle fontStyle;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double wordSpacing;
  final String decoration;

  /// Returns the font-family that should be used to style the paragraph. It may
  /// or may not be different from [fontFamily]:
  ///
  /// - Always returns "Ahem" in tests.
  /// - Provides correct defaults when [fontFamily] doesn't have a value.
  String get effectiveFontFamily {
    if (assertionsEnabled) {
      // In widget tests we use a predictable-size font "Ahem". This makes
      // widget tests predictable and less flaky.
      if (domRenderer.debugIsInWidgetTest) {
        return 'Ahem';
      }
    }
    if (fontFamily == null || fontFamily.isEmpty) {
      return DomRenderer.defaultFontFamily;
    }
    return fontFamily;
  }

  String _cssFontString;

  /// Cached font string that can be used in CSS.
  ///
  /// See <https://developer.mozilla.org/en-US/docs/Web/CSS/font>.
  String get cssFontString {
    if (_cssFontString == null) {
      _cssFontString = _buildCssFontString();
    }
    return _cssFontString;
  }

  String _buildCssFontString() {
    final result = StringBuffer();

    // Font style
    if (fontStyle != null) {
      result.write(fontStyle == ui.FontStyle.normal ? 'normal' : 'italic');
    } else {
      result.write(DomRenderer.defaultFontStyle);
    }
    result.write(' ');

    // Font weight.
    if (fontWeight != null) {
      result.write(ui.webOnlyFontWeightToCss(fontWeight));
    } else {
      result.write(DomRenderer.defaultFontWeight);
    }
    result.write(' ');

    if (fontSize != null) {
      result.write(fontSize.floor());
      result.write('px');
    } else {
      result.write(DomRenderer.defaultFontSize);
    }
    result.write(' ');
    result.write(effectiveFontFamily);

    return result.toString();
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    final ParagraphGeometricStyle typedOther = other;
    if (fontWeight != typedOther.fontWeight ||
        fontStyle != typedOther.fontStyle ||
        fontFamily != typedOther.fontFamily ||
        fontSize != typedOther.fontSize ||
        lineHeight != typedOther.lineHeight ||
        letterSpacing != typedOther.letterSpacing ||
        wordSpacing != typedOther.wordSpacing ||
        decoration != typedOther.decoration) return false;
    return true;
  }

  @override
  int get hashCode => ui.hashValues(
        fontWeight,
        fontStyle,
        fontFamily,
        fontSize,
        lineHeight,
        letterSpacing,
        wordSpacing,
        decoration,
      );

  @override
  String toString() {
    if (assertionsEnabled) {
      return '$runtimeType(fontWeight: $fontWeight, fontStyle: $fontStyle,'
          ' fontFamily: $fontFamily, fontSize: $fontSize,'
          ' lineHeight: $lineHeight)'
          ' letterSpacing: $letterSpacing)'
          ' wordSpacing: $wordSpacing)'
          ' decoration: $decoration)';
    } else {
      return super.toString();
    }
  }
}

/// Provides text dimensions found on [_element]. The idea behind this class is
/// to allow the [ParagraphRuler] to mutate multiple dom elements and allow
/// consumers to lazily read the measurements.
///
/// The [ParagraphRuler] would have multiple instances of [TextDimensions] with
/// different backing elements for different types of measurements. When a
/// measurement is needed, the [ParagraphRuler] would mutate all the backing
/// elements at once. The consumer of the ruler can later read those
/// measurements.
///
/// The rationale behind this is to minimize browser reflows by batching dom
/// writes first, then performing all the reads.
class TextDimensions {
  TextDimensions(this._element, [this._probe]);

  final html.HtmlElement _element;
  final html.HtmlElement _probe;

  /// The width of the paragraph being measured.
  double get width => _element.getBoundingClientRect().width;

  /// The height of the paragraph being measured.
  double get height => _element.getBoundingClientRect().height;

  /// The alphabetic baseline of the paragraph being measured.
  double get alphabeticBaseline => _probe.getBoundingClientRect().bottom;
}

/// Performs 3 types of measurements:
///
/// 1. Single line: can be prepared by calling [measureAsSingleLine].
///    Measurement values will be available at [singleLineDimensions].
///
/// 2. Minimum intrinsic width: can be prepared by calling
///    [measureMinIntrinsicWidth]. Measurement values will be available at
///    [minIntrinsicDimensions].
///
/// 3. Constrained: can be prepared by calling [measureWithConstraints] and
///    passing the constraints. Measurement values will be available at
///    [constrainedDimensions].
///
/// For performance reasons, it's advised to use [measureAll] and then reading
/// whatever measurements are needed. This causes the browser to only reflow
/// once instead of many times.
///
/// This class is both reusable and stateful. Use it carefully. The correct
/// usage is as follows:
///
/// * First, call [willMeasure] passing it the paragraph to be measured.
/// * Call any of the [measureAsSingleLine], [measureMinIntrinsicWidth],
///   [measureWithConstraints], or [measureAll], to prepare the respective
///   measurement. These methods can be called any number of times.
/// * Call [didMeasure] to indicate that you are done with the paragraph passed
///   to the [willMeasure] method.
///
/// It is safe to reuse this object as long as paragraphs passed to the
/// [measure] method have the same style.
///
/// This class optimizes for plain text paragraphs, which should constitute the
/// majority of paragraphs in typical apps.
class ParagraphRuler {
  ParagraphRuler(this.style) {
    _configureSingleLineHostElements();
    _configureMinIntrinsicHostElements();
    _configureConstrainedHostElements();
  }

  /// The only style that this [ParagraphRuler] measures text.
  final ParagraphGeometricStyle style;

  // Elements used to measure single-line metrics.
  final html.DivElement _singleLineHost = html.DivElement();
  final TextDimensions singleLineDimensions =
      TextDimensions(html.ParagraphElement(), html.DivElement());

  // Elements used to measure minIntrinsicWidth.
  final html.DivElement _minIntrinsicHost = html.DivElement();
  TextDimensions minIntrinsicDimensions =
      TextDimensions(html.ParagraphElement());

  // Elements used to measure metrics under a width constraint.
  final html.DivElement _constrainedHost = html.DivElement();
  // TODO(mdebbar): Can we remove the probe from this one?
  TextDimensions constrainedDimensions =
      TextDimensions(html.ParagraphElement(), html.DivElement());

  /// The number of times this ruler was used this frame.
  ///
  /// This value is used to determine which rulers are rarely used and should be
  /// evicted from the ruler cache.
  int get hitCount => _hitCount;
  int _hitCount = 0;

  /// Resets the hit count back to zero.
  void resetHitCount() {
    _hitCount = 0;
  }

  /// Makes sure this ruler is not used again after it has been disposed of,
  /// which would indicate a bug.
  bool get debugIsDisposed => _debugIsDisposed;
  bool _debugIsDisposed = false;

  void _configureSingleLineHostElements() {
    _singleLineHost.style
      ..visibility = 'hidden'
      ..position = 'absolute'
      ..top = '0' // this is important as baseline == probe.bottom
      ..left = '0'
      ..display = 'flex'
      ..flexDirection = 'row'
      ..alignItems = 'baseline'
      ..margin = '0'
      ..border = '0'
      ..padding = '0';

    _applyStyle(singleLineDimensions._element);

    // Force single-line (even if wider than screen) and preserve whitespaces.
    singleLineDimensions._element.style.whiteSpace = 'pre';

    _singleLineHost
      ..append(singleLineDimensions._element)
      ..append(singleLineDimensions._probe);
    TextMeasurementService.instance.addHostElement(_singleLineHost);
  }

  void _configureMinIntrinsicHostElements() {
    // Configure min intrinsic host elements.
    _minIntrinsicHost.style
      ..visibility = 'hidden'
      ..position = 'absolute'
      ..top = '0' // this is important as baseline == probe.bottom
      ..left = '0'
      ..display = 'flex'
      ..flexDirection = 'row'
      ..margin = '0'
      ..border = '0'
      ..padding = '0';

    _applyStyle(minIntrinsicDimensions._element);

    // "flex: 0" causes the paragraph element to shrink horizontally, exposing
    // its minimum intrinsic width.
    minIntrinsicDimensions._element.style
      ..flex = '0'
      ..display = 'inline'
      // Preserve whitespaces.
      ..whiteSpace = 'pre-wrap';

    _minIntrinsicHost.append(minIntrinsicDimensions._element);
    TextMeasurementService.instance.addHostElement(_minIntrinsicHost);
  }

  void _configureConstrainedHostElements() {
    _constrainedHost.style
      ..visibility = 'hidden'
      ..position = 'absolute'
      ..top = '0' // this is important as baseline == probe.bottom
      ..left = '0'
      ..display = 'flex'
      ..flexDirection = 'row'
      ..alignItems = 'baseline'
      ..margin = '0'
      ..border = '0'
      ..padding = '0';

    _applyStyle(constrainedDimensions._element);
    constrainedDimensions._element.style
      ..display = 'block'
      // Preserve whitespaces.
      ..whiteSpace = 'pre-wrap';

    _constrainedHost
      ..append(constrainedDimensions._element)
      ..append(constrainedDimensions._probe);
    TextMeasurementService.instance.addHostElement(_constrainedHost);
  }

  /// Applies geometric style properties to the [element].
  void _applyStyle(html.ParagraphElement element) {
    element.style
      ..fontSize = style.fontSize != null ? '${style.fontSize.floor()}px' : null
      ..fontFamily = style.effectiveFontFamily
      ..fontWeight = style.fontWeight != null
          ? ui.webOnlyFontWeightToCss(style.fontWeight)
          : null
      ..fontStyle = style.fontStyle != null
          ? style.fontStyle == ui.FontStyle.normal ? 'normal' : 'italic'
          : null
      ..letterSpacing =
          style.letterSpacing != null ? '${style.letterSpacing}px' : null
      ..wordSpacing =
          style.wordSpacing != null ? '${style.wordSpacing}px' : null
      ..textDecoration = style.decoration;
    if (style.lineHeight != null) {
      element.style.lineHeight = style.lineHeight.toString();
    }
  }

  /// Attempts to efficiently copy text from [from] into [into].
  ///
  /// The primary efficiency gain is from rare occurrence of rich text in
  /// typical apps.
  void _copyText({
    @required ui.Paragraph from,
    @required html.ParagraphElement into,
  }) {
    assert(from != null);
    assert(into != null);
    assert(from.webOnlyDebugHasSameRootStyle(style));
    assert(() {
      bool wasEmptyOrPlainText = into.childNodes.isEmpty ||
          (into.childNodes.length == 1 && into.childNodes.first is html.Text);
      if (!wasEmptyOrPlainText) {
        throw Exception(
            'Failed to copy text into the paragraph measuring element. The '
            'element already contains rich text "${into.innerHtml}". It is '
            'likely that a previous measurement did not clean up after '
            'itself.');
      }
      return true;
    }());

    String plainText = from.webOnlyGetPlainText();
    if (plainText != null) {
      // Plain text: just set the string. The paragraph's style is assumed to
      // match the style set on the `element`. Setting text as plain string is
      // faster because it doesn't change the DOM structure or CSS attributes,
      // and therefore doesn't trigger style recalculations in the browser.
      into.text = plainText;
    } else {
      // Rich text: deeply copy contents. This is the slow case that should be
      // avoided if fast layout performance is desired.
      final html.Element copy = from.webOnlyGetParagraphElement().clone(true);
      into.nodes.addAll(copy.childNodes);
    }
  }

  /// The paragraph being measured.
  ui.Paragraph _paragraph;

  /// Prepares this ruler for measuring the given [paragraph].
  ///
  /// This method must be called before calling any of the `measure*` methods.
  void willMeasure(ui.Paragraph paragraph) {
    assert(paragraph != null);
    assert(() {
      if (_paragraph != null) {
        throw Exception(
            'Attempted to reuse a $ParagraphRuler but it is currently '
            'measuring another paragraph ($_paragraph). It is possible that ');
      }
      return true;
    }());
    assert(paragraph.webOnlyDebugHasSameRootStyle(style));
    _hitCount += 1;
    _paragraph = paragraph;
  }

  /// Prepares all 3 measurements:
  /// 1. single line.
  /// 2. minimum intrinsic width.
  /// 3. constrained.
  void measureAll(ui.ParagraphConstraints constraints) {
    measureAsSingleLine();
    measureMinIntrinsicWidth();
    measureWithConstraints(constraints);
  }

  /// Lays out the paragraph in a single line, giving it infinite amount of
  /// horizontal space.
  ///
  /// Measures [width], [height], and [alphabeticBaseline].
  void measureAsSingleLine() {
    assert(!_debugIsDisposed);
    assert(_paragraph != null);

    // HACK(mdebbar): TextField uses an empty string to measure the line height,
    // which doesn't work. So we need to replace it with a whitespace. The
    // correct fix would be to do line height and baseline measurements and
    // cache them separately.
    if (_paragraph.webOnlyGetPlainText() == '') {
      singleLineDimensions._element.text = ' ';
    } else {
      _copyText(from: _paragraph, into: singleLineDimensions._element);
    }
  }

  /// Lays out the paragraph inside a flex row and sets "flex: 0", which
  /// squeezes the paragraph, forcing it to occupy minimum intrinsic width.
  ///
  /// Measures [width] and [height].
  void measureMinIntrinsicWidth() {
    assert(!_debugIsDisposed);
    assert(_paragraph != null);

    _copyText(from: _paragraph, into: minIntrinsicDimensions._element);
  }

  /// Lays out the paragraph giving it a width constraint.
  ///
  /// Measures [width], [height], and [alphabeticBaseline].
  void measureWithConstraints(ui.ParagraphConstraints constraints) {
    assert(!_debugIsDisposed);
    assert(_paragraph != null);

    _copyText(from: _paragraph, into: constrainedDimensions._element);

    // The extra 0.5 is because sometimes the browser needs slightly more space
    // than the size it reports back. When that happens the text may be wrap
    // when we thought it didn't.
    constrainedDimensions._element.style.width = '${constraints.width + 0.5}px';
  }

  /// Performs clean-up after a measurement is done, preparing this ruler for
  /// a future reuse.
  ///
  /// Call this method immediately after calling `measure*` methods for a
  /// particular [paragraph]. This ruler is not reusable until [didMeasure] is
  /// called.
  void didMeasure() {
    assert(_paragraph != null);
    // Remove any rich text we set during layout for the following reasons:
    // - there won't be any text for the browser to lay out when we commit the
    //   current frame.
    // - this keeps the cost of removing content together with the measurement
    //   in the profile. Otherwise, the cost of removing will be paid by a
    //   random next paragraph measured in the future, and make the performance
    //   profile hard to understand.
    //
    // We do not do this for plain text, because replacing plain text is more
    // expensive than paying the cost of the DOM mutation to clean it.
    if (_paragraph.webOnlyGetPlainText() == null) {
      domRenderer.clearDom(singleLineDimensions._element);
      domRenderer.clearDom(minIntrinsicDimensions._element);
      domRenderer.clearDom(constrainedDimensions._element);
    }
    _paragraph = null;
  }

  /// Detaches this ruler from the DOM and makes it unusable for future
  /// measurements.
  ///
  /// Disposed rulers should be garbage collected after calling this method.
  void dispose() {
    assert(() {
      if (_paragraph != null) {
        throw Exception('Attempted to dispose of a ruler in the middle of '
            'measurement. This is likely a bug in the framework.');
      }
      return true;
    }());
    _singleLineHost.remove();
    _minIntrinsicHost.remove();
    _constrainedHost.remove();
    assert(() {
      _debugIsDisposed = true;
      return true;
    }());
  }
}
