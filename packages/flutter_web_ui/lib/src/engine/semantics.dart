// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter_web_ui/ui.dart' as ui;

import '../util.dart' as util;

import 'alarm_clock.dart';

/// Set this flag to `true` to cause the engine to visualize the semantics tree
/// on the screen.
///
/// This is useful for debugging.
const bool _debugShowSemanticsNodes = false;

/// Contains updates for the semantics tree.
///
/// This class provides private engine-side API that's not available in the
/// `dart:ui` [ui.SemanticsUpdate].
class SemanticsUpdate implements ui.SemanticsUpdate {
  SemanticsUpdate({List<SemanticsNodeUpdate> nodeUpdates})
      : _nodeUpdates = nodeUpdates;

  /// Updates for individual nodes.
  final List<SemanticsNodeUpdate> _nodeUpdates;

  @override
  void dispose() {
    // Intentionally left blank. This method exists for API compatibility with
    // Flutter, but it is not required as memory resource management is handled
    // by JavaScript's garbage collector.
  }
}

/// Updates the properties of a particular semantics node.
class SemanticsNodeUpdate {
  SemanticsNodeUpdate({
    this.id,
    this.flags,
    this.actions,
    this.textSelectionBase,
    this.textSelectionExtent,
    this.scrollChildren,
    this.scrollIndex,
    this.scrollPosition,
    this.scrollExtentMax,
    this.scrollExtentMin,
    this.rect,
    this.label,
    this.hint,
    this.value,
    this.increasedValue,
    this.decreasedValue,
    this.textDirection,
    this.transform,
    this.elevation,
    this.thickness,
    this.childrenInTraversalOrder,
    this.childrenInHitTestOrder,
    this.additionalActions,
  });

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int id;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int flags;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int actions;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int textSelectionBase;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int textSelectionExtent;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int scrollChildren;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int scrollIndex;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double scrollPosition;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double scrollExtentMax;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double scrollExtentMin;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final ui.Rect rect;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String label;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String hint;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String value;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String increasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String decreasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final ui.TextDirection textDirection;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Float64List transform;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Int32List childrenInTraversalOrder;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Int32List childrenInHitTestOrder;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Int32List additionalActions;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double elevation;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double thickness;
}

/// Instantiation of a framework-side semantics node in the DOM.
///
/// Instances of this class are retained from frame to frame. Each instance is
/// permanently attached to an [id] and a DOM [element] used to convey semantics
/// information to the browser.
class SemanticsObject {
  /// Creates a semantics tree node with the given [id] and [owner].
  SemanticsObject(this.id, this.owner) {
    // DOM nodes created for semantics objects are positioned absolutely using
    // transforms. We use a transparent color instead of "visibility:hidden" or
    // "display:none" so that a screen reader does not ignore these elements.
    element.style.position = 'absolute';

    // The root node has some properties that other nodes do not.
    if (id == 0) {
      // Make all semantics transparent
      element.style.opacity = '0';

      // Make text explicitly transparent to signal to the browser that no
      // rasterization needs to be done.
      element.style.color = 'rgba(0,0,0,0)';
    }

    if (_debugShowSemanticsNodes) {
      element.style.outline = '1px solid green';
      element.style.color = 'purple';
    }
  }

  /// A unique permanent identifier of the semantics node in the tree.
  final int id;

  /// Controls the semantics tree that this node participates in.
  final EngineSemanticsOwner owner;

  /// The DOM element used to convey semantics information to the browser.
  final html.Element element = html.Element.tag('flt-semantics');

  /// Returns the HTML element that contains the HTML elements of direct
  /// children of this object.
  ///
  /// The element is created lazily. When the child list is empty this element
  /// is not created. This is necessary for "aria-label" to function correctly.
  /// The browser will ignore the [label] of HTML element that contain child
  /// elements.
  html.Element getOrCreateChildContainer() {
    if (_childContainerElement == null) {
      _childContainerElement = html.Element.tag('flt-semantics-container');
      _childContainerElement.style.position = 'absolute';
      element.append(_childContainerElement);
    }
    return _childContainerElement;
  }

  /// The element that contains the elements belonging to the child semantics
  /// nodes.
  ///
  /// This element is used to correct for [_rect] offsets. It is only non-`null`
  /// when there are non-zero children (i.e. when [hasChildren] is `true`).
  html.Element _childContainerElement;

  /// This element renders the [value] to semantics as text content.
  html.Element _valueElement;

  /// Displays the value of [_label] as its text content when
  /// [_debugShowSemanticsNodes] is true.
  html.Element _debugLabelElement;

  /// Listens to HTML "click" gestures detected by the browser.
  ///
  /// This gestures is different from the click and tap gestures detected by the
  /// framework from raw pointer events. When an assistive technology is enabled
  /// the browser may not send us pointer events. In that mode we forward HTML
  /// click as [ui.SemanticsAction.tap].
  html.EventListener _clickListener;

  /// Listens to HTML "scroll" gestures detected by the browser.
  ///
  /// This gesture is converted to [ui.SemanticsAction.scrollUp] or
  /// [ui.SemanticsAction.scrollDown], depending on the direction.
  html.EventListener _scrollListener;

  /// The parent of this semantics object.
  SemanticsObject _parent;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int _flags;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int _actions;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int _textSelectionBase;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int _textSelectionExtent;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int _scrollChildren;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int _scrollIndex;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  double _scrollPosition;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  double _scrollExtentMax;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  double _scrollExtentMin;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  ui.Rect _rect;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String _label;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String _hint;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String _value;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String _increasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String _decreasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  ui.TextDirection _textDirection;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Float64List _transform;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Int32List _childrenInTraversalOrder;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Int32List _childrenInHitTestOrder;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Int32List _additionalActions;

  /// Whether this node currently has a given [SemanticsFlag].
  bool hasFlag(ui.SemanticsFlag flag) => _flags & flag.index != 0;

  /// Whether [actions] contains the given action.
  bool hasAction(ui.SemanticsAction action) => (_actions & action.index) != 0;

  /// Whether this object represents a vertically scrollable area.
  bool get isVerticalScrollContainer =>
      hasAction(ui.SemanticsAction.scrollDown) ||
      hasAction(ui.SemanticsAction.scrollUp);

  /// Whether this object represents a hotizontally scrollable area.
  bool get isHorizontalScrollContainer =>
      hasAction(ui.SemanticsAction.scrollLeft) ||
      hasAction(ui.SemanticsAction.scrollRight);

  /// Whether this object has a non-empty list of children.
  bool get hasChildren =>
      _childrenInTraversalOrder != null && _childrenInTraversalOrder.isNotEmpty;

  /// The value of the "scrollTop" or "scrollLeft" property of this object's
  /// [element] that has zero offset relative to the [scrollPosition].
  int _effectiveNeutralScrollPosition = 0;

  /// The value of "scrollTop" or "scrollLeft", depending on the scroll axis.
  int get _domScrollPosition {
    if (isVerticalScrollContainer) {
      return element.scrollTop;
    } else {
      assert(isHorizontalScrollContainer);
      return element.scrollLeft;
    }
  }

  /// Resets the scroll position (top or left) to the neutral value.
  ///
  /// The scroll position of the scrollable HTML node that's considered to
  /// have zero offset relative to Flutter's notion of scroll position is
  /// referred to as "neutral scroll position".
  ///
  /// We always set the the scroll position to a non-zero value in order to
  /// be able to scroll in the negative direction. When scrollTop/scrollLeft is
  /// zero the browser will refuse to scroll back even when there is more
  /// content available.
  void _neutralizeDomScrollPosition() {
    // This value is arbitrary.
    const int _canonicalNeutralScrollPosition = 10;

    if (isVerticalScrollContainer) {
      element.scrollTop = _canonicalNeutralScrollPosition;
      // Read back because the effective value depends on the amount of content.
      _effectiveNeutralScrollPosition = element.scrollTop;
    } else {
      element.scrollLeft = _canonicalNeutralScrollPosition;
      // Read back because the effective value depends on the amount of content.
      _effectiveNeutralScrollPosition = element.scrollLeft;
    }
  }

  /// Updates this object from data received from a semantics [update].
  ///
  /// This method creates [SemanticsObject]s for the direct children of this
  /// object. However, it does not recursively populate them.
  void updateWith(SemanticsNodeUpdate update) {
    // TODO(yjbanov): implement all flags.
    if (_flags != update.flags) {
      _flags = update.flags;

      if (hasFlag(ui.SemanticsFlag.isButton)) {
        element.setAttribute('role', 'button');
      } else if (hasFlag(ui.SemanticsFlag.isImage)) {
        element.setAttribute('role', 'img');
      } else {
        element.attributes.remove('role');
      }
    }

    // Update value early because some controls, such as incrementables, depend
    // on it.
    bool valueChanged = false;
    if (_value != update.value) {
      _value = update.value;
      valueChanged = true;
    }

    // TODO(yjbanov): implement all actions.
    if (_actions != update.actions) {
      _actions = update.actions;
      _updateTapHandling();
      _updateScrollHandling();
      _updateIncrementHandling();
    }

    if (_label != update.label) {
      _label = update.label;
      if (update.label != null && update.label.isNotEmpty) {
        element.setAttribute('aria-label', _label);
        if (_debugShowSemanticsNodes) {
          _debugLabelElement ??= html.Element.tag('flt-debug-label');
          _debugLabelElement.text = _label;
          element.append(_debugLabelElement);
        }
      } else {
        element.attributes.remove('aria-label');
        if (_debugShowSemanticsNodes) {
          _debugLabelElement?.remove();
        }
      }
    }

    if (valueChanged) {
      final bool hasValue = _value != null && _value.isNotEmpty;
      // If the node is incrementable the value is reported to the browser via
      // the <input> tag, so we do not need to also render it again here.
      final bool shouldDisplayValue = hasValue && !isIncrementable;
      if (shouldDisplayValue) {
        if (_valueElement == null) {
          _valueElement = html.Element.tag('flt-semantics-value');
          _valueElement.style
            ..position = 'absolute'
            ..top = '0'
            ..right = '0'
            ..bottom = '0'
            ..left = '0';
          element.append(_valueElement);
        }
        _valueElement.text = _value;
      } else {
        _valueElement?.remove();
      }
    }

    if (_textSelectionBase != update.textSelectionBase) {
      _textSelectionBase = update.textSelectionBase;
      // TODO(yjbanov): implement textSelectionBase.
    }

    if (_textSelectionExtent != update.textSelectionExtent) {
      _textSelectionExtent = update.textSelectionExtent;
      // TODO(yjbanov): implement textSelectionExtent.
    }

    if (_scrollChildren != update.scrollChildren) {
      _scrollChildren = update.scrollChildren;
      // TODO(yjbanov): implement scrollChildren.
    }

    if (_scrollIndex != update.scrollIndex) {
      _scrollIndex = update.scrollIndex;
      // TODO(yjbanov): implement scrollIndex.
    }

    if (_scrollExtentMax != update.scrollExtentMax) {
      _scrollExtentMax = update.scrollExtentMax;
      // TODO(yjbanov): implement scrollExtentMax.
    }

    if (_scrollExtentMin != update.scrollExtentMin) {
      _scrollExtentMin = update.scrollExtentMin;
      // TODO(yjbanov): implement scrollExtentMin.
    }

    if (_hint != update.hint) {
      _hint = update.hint;
      // TODO(yjbanov): implement hint.
    }

    if (_increasedValue != update.increasedValue ||
        _decreasedValue != update.decreasedValue) {
      _increasedValue = update.increasedValue;
      _decreasedValue = update.decreasedValue;
      _updateIncrementHandling();
    }

    if (_textDirection != update.textDirection) {
      _textDirection = update.textDirection;
      // TODO(yjbanov): implement textDirection.
    }

    if (_childrenInHitTestOrder != update.childrenInHitTestOrder) {
      _childrenInHitTestOrder = update.childrenInHitTestOrder;
      // TODO(yjbanov): implement childrenInHitTestOrder.
    }

    if (_additionalActions != update.additionalActions) {
      _additionalActions = update.additionalActions;
      // TODO(yjbanov): implement additionalActions.
    }

    _updateChildrenInTraversalOrder(update);

    // All properties that affect positioning and sizing are checked together
    // any one of them triggers position and size recomputation.
    // Positioning and sizing must take place after child list update because
    // they depend on the presence of children.
    if (_rect != update.rect ||
        _transform != update.transform ||
        _scrollPosition != update.scrollPosition) {
      _transform = update.transform;
      _rect = update.rect;
      _scrollPosition = update.scrollPosition;
      _recomputePositionAndSize();
    }

    // Make sure we create a child container only when there are children.
    assert(_childContainerElement == null || hasChildren);
  }

  void _updateTapHandling() {
    if (_clickListener != null) {
      element.removeEventListener('click', _clickListener);
      _clickListener = null;
    }

    if (hasAction(ui.SemanticsAction.tap)) {
      _clickListener = (_) {
        if (!owner.shouldAcceptBrowserGesture('click')) {
          return;
        }
        ui.window.onSemanticsAction(id, ui.SemanticsAction.tap, null);
      };
      element.addEventListener('click', _clickListener);
    }
  }

  void _updateScrollHandling() {
    final html.CssStyleDeclaration style = element.style;
    if (isVerticalScrollContainer || isHorizontalScrollContainer) {
      if (_scrollListener == null) {
        // We need to set touch-action:none explicitly here, despite the fact
        // that we already have it on the <body> tag because overflow:scroll
        // still causes the browser to take over pointer events in order to
        // process scrolling. We don't want that when scrolling is handled by
        // the framework.
        //
        // This is effective only in Chrome. Safari does not implement this
        // CSS property. In Safari the `PointerBinding` uses `preventDefault`
        // to prevent browser scrolling.
        style.touchAction = 'none';
        _gestureModeDidChange(owner._gestureMode);

        // We neutralize the scroll position after all children have been
        // updated. Otherwise the browser does not yet have the sizes of the
        // child nodes and resets the scrollTop value back to zero.
        owner._addOneTimePostUpdateCallback(() {
          _neutralizeDomScrollPosition();
        });

        // Memoize the tear-off because Dart does not guarantee that two
        // tear-offs of a method on the same instance will produce the same
        // object.
        _gestureModeListener = _gestureModeDidChange;
        owner._addGestureModeListener(_gestureModeListener);

        _scrollListener = (_) {
          _recomputeScrollPosition();
        };
        element.addEventListener('scroll', _scrollListener);
      }
    } else {
      style.removeProperty('overflowY');
      style.removeProperty('overflowX');
      style.removeProperty('touch-action');
      if (_scrollListener != null) {
        element.removeEventListener('scroll', _scrollListener);
      }
      if (_gestureModeListener != null) {
        owner._removeGestureModeListener(_gestureModeListener);
        _gestureModeListener = null;
      }
    }
  }

  IncrementHandler _incrementHandler;

  /// Whether the object represents an UI element with "increase" or "decrease"
  /// controls, e.g. a slider.
  ///
  /// Such objects are expressed in HTML using `<input type="range">`.
  bool get isIncrementable =>
      hasAction(ui.SemanticsAction.increase) ||
      hasAction(ui.SemanticsAction.decrease);

  void _updateIncrementHandling() {
    if (isIncrementable) {
      if (_incrementHandler == null) {
        _incrementHandler = IncrementHandler(this);
      }
      _incrementHandler.update();
    } else if (_incrementHandler != null) {
      _incrementHandler.dispose();
      _incrementHandler = null;
    }
  }

  GestureModeCallback _gestureModeListener;

  void _gestureModeDidChange(GestureMode mode) {
    switch (mode) {
      case GestureMode.browserGestures:
        // overflow:scroll will cause the browser report "scroll" events when
        // the accessibility focus shifts outside the visible bounds.
        //
        // Note that on Android overflow:hidden also works. However, we prefer
        // "scroll" because it works both on Android and iOS.
        if (isVerticalScrollContainer) {
          element.style.overflowY = 'scroll';
        } else {
          assert(isHorizontalScrollContainer);
          element.style.overflowX = 'scroll';
        }
        break;
      case GestureMode.pointerEvents:
        // We use "hidden" instead of "scroll" so that the browser does
        // not "steal" pointer events. Flutter gesture recognizers need
        // all pointer events in order to recognize gestures correctly.
        if (isVerticalScrollContainer) {
          element.style.overflowY = 'hidden';
        } else {
          assert(isHorizontalScrollContainer);
          element.style.overflowX = 'hidden';
        }
        break;
    }
  }

  /// This method responds to browser-detected "scroll" gestures.
  ///
  /// Scrolling is implemented using a "joystick" method. The absolute value of
  /// "scrollTop" in HTML is not important. We only need to know in whether the
  /// value changed in the positive or negative direction. If it changes in the
  /// positive direction we send a [ui.SemanticsAction.scrollUp]. Otherwise, we
  /// send [ui.SemanticsAction.scrollDown]. The actual scrolling is then handled
  /// by the framework and we receive a [ui.SemanticsUpdate] containing the new
  /// [scrollPosition] and child positions.
  ///
  /// "scrollTop" or 'scrollLeft" is always reset to an arbitrarily chosen non-
  /// zero "neutral" scroll position value. This is done so we have a
  /// predictable range of DOM scroll position values. When the amount of
  /// contents is less than the size of the viewport the browser snaps
  /// "scrollTop" back to zero. If there is more content than available in the
  /// viewport "scrollTop" may take positive values. We memorize the effective
  /// neutral "scrollTop" value in [_effectiveNeutralScrollPosition].
  void _recomputeScrollPosition() {
    if (_domScrollPosition != _effectiveNeutralScrollPosition) {
      if (!owner.shouldAcceptBrowserGesture('scroll')) {
        return;
      }
      final bool doScrollForward =
          _domScrollPosition > _effectiveNeutralScrollPosition;
      _neutralizeDomScrollPosition();
      _recomputePositionAndSize();

      if (doScrollForward) {
        if (isVerticalScrollContainer) {
          ui.window.onSemanticsAction(id, ui.SemanticsAction.scrollUp, null);
        } else {
          assert(isHorizontalScrollContainer);
          ui.window.onSemanticsAction(id, ui.SemanticsAction.scrollLeft, null);
        }
      } else {
        if (isVerticalScrollContainer) {
          ui.window.onSemanticsAction(id, ui.SemanticsAction.scrollDown, null);
        } else {
          assert(isHorizontalScrollContainer);
          ui.window.onSemanticsAction(id, ui.SemanticsAction.scrollRight, null);
        }
      }
    }
  }

  /// Computes the size and position of [element] and, if this element
  /// [hasChildren], of [_childContainerElement].
  void _recomputePositionAndSize() {
    element.style
      ..width = '${_rect.width}px'
      ..height = '${_rect.height}px';

    final html.Element containerElement =
        hasChildren ? getOrCreateChildContainer() : null;

    bool hasZeroRectOffset = _rect.top == 0.0 && _rect.left == 0.0;
    bool hasIdentityTransform =
        _transform == null || util.isIdentityFloat64ListTransform(_transform);

    if (hasZeroRectOffset &&
        hasIdentityTransform &&
        _effectiveNeutralScrollPosition == 0) {
      element.style
        ..removeProperty('transform-origin')
        ..removeProperty('transform');
      if (containerElement != null) {
        containerElement.style
          ..removeProperty('transform-origin')
          ..removeProperty('transform');
      }
      return;
    }

    Matrix4 effectiveTransform =
        Matrix4.fromFloat64List(_transform ?? Matrix4.identity());
    if (!hasZeroRectOffset) {
      // Clone to avoid mutating _transform.
      effectiveTransform = effectiveTransform.clone();
      effectiveTransform.translate(_rect.left, _rect.top, 0.0);
    }

    if (!effectiveTransform.isIdentity()) {
      element.style
        ..transformOrigin = '0 0 0'
        ..transform = util.matrix4ToCssTransform(effectiveTransform);
    } else {
      element.style
        ..removeProperty('transform-origin')
        ..removeProperty('transform');
    }

    if (containerElement != null) {
      if (!hasZeroRectOffset || _effectiveNeutralScrollPosition != 0) {
        double translateX = -_rect.left;
        double translateY = -_rect.top;

        if (_effectiveNeutralScrollPosition != 0) {
          if (isVerticalScrollContainer) {
            translateY += _effectiveNeutralScrollPosition;
          } else {
            assert(isHorizontalScrollContainer);
            translateX += _effectiveNeutralScrollPosition;
          }
        }

        containerElement.style
          ..transformOrigin = '0 0 0'
          ..transform = 'translate(${translateX}px, ${translateY}px)';
      } else {
        containerElement.style
          ..removeProperty('transform-origin')
          ..removeProperty('transform');
      }
    }
  }

  /// Updates the traversal child list of [object] from the given [update].
  ///
  /// This method does not recursively update child elements' properties or
  /// their grandchildren. This is handled by [updateSemantics] method walking
  /// all the update nodes.
  void _updateChildrenInTraversalOrder(SemanticsNodeUpdate update) {
    // Remove all children case.
    if (update.childrenInTraversalOrder == null ||
        update.childrenInTraversalOrder.isEmpty) {
      if (_childrenInTraversalOrder == null ||
          _childrenInTraversalOrder.isEmpty) {
        // We must not have created a container element when child list is empty.
        assert(_childContainerElement == null);
        _childrenInTraversalOrder = update.childrenInTraversalOrder;
        return;
      }

      // We must have created a container element when child list is not empty.
      assert(_childContainerElement != null);

      // Remove all children from this semantics object.
      for (int childId in _childrenInTraversalOrder) {
        owner._detachObject(childId);
      }
      _childrenInTraversalOrder = null;
      _childContainerElement.remove();
      _childContainerElement = null;
      _childrenInTraversalOrder = update.childrenInTraversalOrder;
      return;
    }

    final html.Element containerElement = getOrCreateChildContainer();

    // Empty case.
    if (_childrenInTraversalOrder == null ||
        _childrenInTraversalOrder.isEmpty) {
      _childrenInTraversalOrder = update.childrenInTraversalOrder;
      for (int id in _childrenInTraversalOrder) {
        final SemanticsObject child = owner.getOrCreateObject(id);
        containerElement.append(child.element);
        owner._attachObject(parent: this, child: child);
      }
      _childrenInTraversalOrder = update.childrenInTraversalOrder;
      return;
    }

    // Both non-empty case.

    // Indices into the new child list pointing at children that also exist in
    // the old child list.
    final List<int> intersectionIndicesNew = <int>[];

    // Indices into the old child list pointing at children that also exist in
    // the new child list.
    final List<int> intersectionIndicesOld = <int>[];

    int newIndex = 0;

    // The smallest of the two child list lengths.
    final int minLength = math.min(
      _childrenInTraversalOrder.length,
      update.childrenInTraversalOrder.length,
    );

    // Scan forward until first discrepancy.
    while (newIndex < minLength &&
        _childrenInTraversalOrder[newIndex] ==
            update.childrenInTraversalOrder[newIndex]) {
      intersectionIndicesNew.add(newIndex);
      intersectionIndicesOld.add(newIndex);
      newIndex += 1;
    }

    // If child lists are identical, do nothing.
    if (_childrenInTraversalOrder.length ==
            update.childrenInTraversalOrder.length &&
        newIndex == update.childrenInTraversalOrder.length) {
      return;
    }

    // If child lists are not identical, continue computing the intersection
    // between the two lists.
    while (newIndex < update.childrenInTraversalOrder.length) {
      for (int oldIndex = 0;
          oldIndex < _childrenInTraversalOrder.length;
          oldIndex += 1) {
        if (_childrenInTraversalOrder[oldIndex] ==
            update.childrenInTraversalOrder[newIndex]) {
          intersectionIndicesNew.add(newIndex);
          intersectionIndicesOld.add(oldIndex);
          break;
        }
      }
      newIndex += 1;
    }

    // The longest sub-sequence in the old list maximizes the number of children
    // that do not need to be moved.
    final List<int> longestSequence =
        longestIncreasingSubsequence(intersectionIndicesOld);
    final List<int> stationaryIds = <int>[];
    for (int i = 0; i < longestSequence.length; i += 1) {
      stationaryIds.add(_childrenInTraversalOrder[
          intersectionIndicesOld[longestSequence[i]]]);
    }

    // Remove children that are no longer in the list.
    for (int i = 0; i < _childrenInTraversalOrder.length; i++) {
      if (!intersectionIndicesOld.contains(i)) {
        // Child not in the intersection. Must be removed.
        final childId = _childrenInTraversalOrder[i];
        owner._detachObject(childId);
      }
    }

    html.Element refNode;
    for (int i = update.childrenInTraversalOrder.length - 1; i >= 0; i -= 1) {
      final int childId = update.childrenInTraversalOrder[i];
      final SemanticsObject child = owner.getOrCreateObject(childId);
      if (!stationaryIds.contains(childId)) {
        if (refNode == null) {
          containerElement.append(child.element);
        } else {
          containerElement.insertBefore(child.element, refNode);
        }
        owner._attachObject(parent: this, child: child);
      } else {
        assert(child._parent == this);
      }
      refNode = child.element;
    }

    _childrenInTraversalOrder = update.childrenInTraversalOrder;
  }

  @override
  String toString() {
    if (util.assertionsEnabled) {
      final String children = _childrenInTraversalOrder != null &&
              _childrenInTraversalOrder.isNotEmpty
          ? '[${_childrenInTraversalOrder.join(', ')}]'
          : '<empty>';
      return '$runtimeType(#${id}, children: ${children})';
    } else {
      return super.toString();
    }
  }
}

/// Adds increment/decrement event handling to a semantics object.
///
/// The implementation uses a hidden `<input type="range">` element with ARIA
/// attributes to cause the browser to render increment/decrement controls to
/// the assistive technology.
///
/// The input element is disabled whenever the gesture mode switches to pointer
/// events. This is to prevent the browser from taking over drag gestures. Drag
/// gestures must be interpreted by the Flutter framework.
class IncrementHandler {
  /// The semantics object managed by this handler.
  final SemanticsObject _semanticsObject;

  /// The HTML element used to render semantics to the browser.
  final html.InputElement _element = html.InputElement();

  /// The value used by the input element.
  ///
  /// Flutter values are strings, and are not necessarily numbers. In order to
  /// convey to the browser what the available "range" of values is we
  /// substitute the framework value with a generated `int` surrogate.
  /// "aria-valuetext" attribute is used to cause the browser to announce the
  /// framework value to the user.
  int _currentSurrogateValue = 1;

  /// Disables the input [_element] when the gesture mode switches to
  /// [GestureMode.pointerEvents], and enables it when the mode switches back to
  /// [GestureMode.browserGestures].
  GestureModeCallback _gestureModeListener;

  IncrementHandler(this._semanticsObject) : assert(_semanticsObject != null) {
    _semanticsObject.element.append(_element);
    _element.type = 'range';
    _element.setAttribute('role', 'slider');

    _element.addEventListener('change', (_) {
      if (_element.disabled) {
        return;
      }
      final int newInputValue = int.parse(_element.value);
      if (newInputValue > _currentSurrogateValue) {
        _currentSurrogateValue += 1;
        ui.window.onSemanticsAction(
            _semanticsObject.id, ui.SemanticsAction.increase, null);
      } else if (newInputValue < _currentSurrogateValue) {
        _currentSurrogateValue -= 1;
        ui.window.onSemanticsAction(
            _semanticsObject.id, ui.SemanticsAction.decrease, null);
      }
    });

    // Update the DOM node once immediately so it reflects the current state of
    // the semantics object.
    update();

    // Store the callback as a closure because Dart does not guarantee that
    // tear-offs produce the same function object.
    _gestureModeListener = (GestureMode mode) {
      update();
    };
    _semanticsObject.owner._addGestureModeListener(_gestureModeListener);
  }

  /// Updates the DOM [_element] based on the current state of the
  /// [_semanticsObject] and current gesture mode.
  void update() {
    switch (_semanticsObject.owner._gestureMode) {
      case GestureMode.browserGestures:
        _enableBrowserGestureHandling();
        _updateInputValues();
        break;
      case GestureMode.pointerEvents:
        _disableBrowserGestureHandling();
        break;
    }
  }

  void _enableBrowserGestureHandling() {
    assert(_semanticsObject.owner._gestureMode == GestureMode.browserGestures);
    if (!_element.disabled) {
      return;
    }
    _element.disabled = false;
  }

  void _updateInputValues() {
    assert(_semanticsObject.owner._gestureMode == GestureMode.browserGestures);
    final String surrogateTextValue = '$_currentSurrogateValue';
    _element.value = surrogateTextValue;
    _element.setAttribute('aria-valuenow', surrogateTextValue);
    _element.setAttribute('aria-valuetext', _semanticsObject._value);

    final bool canIncrease = _semanticsObject._increasedValue != null;
    final String surrogateMaxTextValue =
        canIncrease ? '${_currentSurrogateValue + 1}' : surrogateTextValue;
    _element.max = surrogateMaxTextValue;
    _element.setAttribute('aria-valuemax', surrogateMaxTextValue);

    final bool canDecrease = _semanticsObject._decreasedValue != null;
    final String surrogateMinTextValue =
        canDecrease ? '${_currentSurrogateValue - 1}' : surrogateTextValue;
    _element.min = surrogateMinTextValue;
    _element.setAttribute('aria-valuemin', surrogateMinTextValue);
  }

  void _disableBrowserGestureHandling() {
    if (_element.disabled) {
      return;
    }
    _element.disabled = true;
  }

  /// Cleans up the DOM.
  ///
  /// This object is not usable after calling this method.
  void dispose() {
    assert(_gestureModeListener != null);
    _semanticsObject.owner._removeGestureModeListener(_gestureModeListener);
    _gestureModeListener = null;
    _disableBrowserGestureHandling();
    _element.remove();
  }
}

/// Controls how pointer events and browser-detected gestures are treated by
/// the Web Engine.
enum AccessibilityMode {
  /// We are not told whether the assistive technology is enabled or not.
  ///
  /// This is the default mode.
  ///
  /// In this mode we use a gesture recognition system that deduplicates
  /// gestures detected by Flutter with gestures detected by the browser.
  unknown,

  /// We are told whether the assistive technology is enabled.
  known,
}

/// Called when the current [GestureMode] changes.
typedef GestureModeCallback = void Function(GestureMode mode);

/// The method used to detect user gestures.
enum GestureMode {
  /// Send pointer events to Flutter to detect gestures using framework-level
  /// gesture recognizers and gesture arenas.
  pointerEvents,

  /// Listen to browser-detected gestures and report them to the framework as
  /// [ui.SemanticsAction].
  browserGestures,
}

/// The top-level service that manages everything semantics-related.
class EngineSemanticsOwner {
  EngineSemanticsOwner._();

  /// The singleton instance that manages semantics.
  static EngineSemanticsOwner get instance {
    return _instance ??= EngineSemanticsOwner._();
  }

  static EngineSemanticsOwner _instance;

  /// Disables semantics and uninitializes the singleton [instance].
  ///
  /// Instances of [EngineSemanticsOwner] are no longer valid after calling this
  /// method. Using them will lead to undefined behavior. This method is only
  /// meant to be used for testing.
  static void debugResetSemantics() {
    if (_instance == null) {
      return;
    }
    _instance.semanticsEnabled = false;
    _instance = null;
  }

  final Map<int, SemanticsObject> _semanticsTree = <int, SemanticsObject>{};

  /// Map [SemanticsObject.id] to parent [SemanticsObject] it was attached to
  /// this frame.
  Map<int, SemanticsObject> _attachments = <int, SemanticsObject>{};

  /// Declares that the [child] must be attached to the [parent].
  ///
  /// Attachments take precendence over detachments (see [_detachObject]). This
  /// allows the same node to be detached from one parent in the tree and
  /// reattached to another parent.
  void _attachObject({SemanticsObject parent, SemanticsObject child}) {
    assert(child != null);
    assert(parent != null);
    child._parent = parent;
    _attachments[child.id] = parent;
  }

  /// List of objects that were detached this frame.
  ///
  /// The objects in this list will be detached permanently unless they are
  /// reattached via the [_attachObject] method.
  List<SemanticsObject> _detachments = <SemanticsObject>[];

  /// Declares that the [SemanticsObject] with the given [id] was detached from
  /// its current parent object.
  ///
  /// The object will be detached permanently unless it is reattached via the
  /// [_attachObject] method.
  void _detachObject(int id) {
    assert(_semanticsTree.containsKey(id));
    final SemanticsObject object = _semanticsTree[id];
    _detachments.add(object);
  }

  /// Callbacks called after all objects in the tree have their properties
  /// populated and their sizes and locations computed.
  ///
  /// This list is reset to empty after all callbacks are called.
  List<ui.VoidCallback> _oneTimePostUpdateCallbacks = <ui.VoidCallback>[];

  /// Schedules a one-time callback to be called after all objects in the tree
  /// have their properties populated and their sizes and locations computed.
  void _addOneTimePostUpdateCallback(ui.VoidCallback callback) {
    _oneTimePostUpdateCallbacks.add(callback);
  }

  /// Reconciles [_attachments] and [_detachments], and after that calls all
  /// the one-time callbacks scheduled via the [_addOneTimePostUpdateCallback]
  /// method.
  void _finalizeTree() {
    for (SemanticsObject object in _detachments) {
      final SemanticsObject parent = _attachments[object.id];
      if (parent == null) {
        // Was not reparented and is removed permanently from the tree.
        _semanticsTree.remove(object.id);
        object._parent = null;
        object.element.remove();
      } else {
        assert(object._parent == parent);
        assert(object.element.parent == parent._childContainerElement);
      }
    }
    _detachments = <SemanticsObject>[];
    _attachments = <int, SemanticsObject>{};

    if (_oneTimePostUpdateCallbacks.isNotEmpty) {
      for (ui.VoidCallback callback in _oneTimePostUpdateCallbacks) {
        callback();
      }
      _oneTimePostUpdateCallbacks = <ui.VoidCallback>[];
    }
  }

  /// Returns the entire semantics tree for testing.
  ///
  /// Works only in debug mode.
  Map<int, SemanticsObject> get debugSemanticsTree {
    Map<int, SemanticsObject> result;
    assert(() {
      result = _semanticsTree;
      return true;
    }());
    return result;
  }

  /// The top-level DOM element of the semantics DOM element tree.
  html.Element _rootSemanticsElement;

  TimestampFunction _now = () => DateTime.now();

  void debugOverrideTimestampFunction(TimestampFunction value) {
    _now = value;
  }

  void debugResetTimestampFunction() {
    _now = () => DateTime.now();
  }

  /// Whether the user has requested that [updateSemantics] be called when
  /// the semantic contents of window changes.
  ///
  /// The [ui.Window.onSemanticsEnabledChanged] callback is called whenever this
  /// value changes.
  ///
  /// This is separate from accessibility [mode], which controls how gestures
  /// are interpreted when this value is true.
  bool get semanticsEnabled => _semanticsEnabled;
  bool _semanticsEnabled = false;
  set semanticsEnabled(bool value) {
    if (value == _semanticsEnabled) {
      return;
    }
    _semanticsEnabled = value;

    if (!_semanticsEnabled) {
      // We do not process browser events at all when semantics is explicitly
      // disabled. All gestures are handled by the framework-level gesture
      // recognizers from pointer events.
      if (_gestureMode != GestureMode.pointerEvents) {
        _gestureMode = GestureMode.pointerEvents;
        _notifyGestureModeListeners();
      }
      for (int id in _semanticsTree.keys.toList()) {
        _detachObject(id);
      }
      _finalizeTree();
      _rootSemanticsElement?.remove();
      _rootSemanticsElement = null;
      _gestureModeClock?.datetime = null;
    }

    if (ui.window.onSemanticsEnabledChanged != null) {
      ui.window.onSemanticsEnabledChanged();
    }
  }

  /// Controls how pointer events and browser-detected gestures are treated by
  /// the Web Engine.
  ///
  /// The default mode is [AccessibilityMode.unknown].
  AccessibilityMode get mode => _mode;
  set mode(AccessibilityMode value) {
    assert(value != null);
    _mode = value;
  }

  AccessibilityMode _mode = AccessibilityMode.unknown;

  GestureMode _gestureMode = GestureMode.browserGestures;
  AlarmClock _gestureModeClock;

  AlarmClock _getGestureModeClock() {
    if (_gestureModeClock == null) {
      _gestureModeClock = AlarmClock(_now);
      _gestureModeClock.callback = () {
        if (_gestureMode == GestureMode.browserGestures) {
          return;
        }

        _gestureMode = GestureMode.browserGestures;
        _notifyGestureModeListeners();
      };
    }
    return _gestureModeClock;
  }

  /// Disables browser gestures temporarily because we have detected pointer
  /// events.
  ///
  /// This is used to deduplicate gestures detected by Flutter and gestures
  /// detected by the browser. Flutter-detected gestures have higher precedence.
  void _temporarilyDisableBrowserGestureMode() {
    const _kDebounceThreshold = Duration(milliseconds: 500);
    _getGestureModeClock().datetime = _now().add(_kDebounceThreshold);
    if (_gestureMode != GestureMode.pointerEvents) {
      _gestureMode = GestureMode.pointerEvents;
      _notifyGestureModeListeners();
    }
  }

  /// Receives DOM events from the pointer event system to correlate with the
  /// semantics events.
  ///
  /// The browser sends us both raw pointer events and gestures from
  /// [SemanticsObject.element]s. There could be three possibilities:
  ///
  /// 1. Assistive technology is enabled and we know that it is.
  /// 2. Assistive technology is disabled and we know that it isn't.
  /// 3. We do not know whether an assistive technology is enabled.
  ///
  /// In the first case we can ignore raw pointer events and only interpret
  /// high-level gestures, e.g. "click".
  ///
  /// In the second case we can ignore high-level gestures and interpret the raw
  /// pointer events directly.
  ///
  /// Finally, in a mode when we do not know if an assistive technology is
  /// enabled or not we do a best-effort estimate which to respond to, raw
  /// pointer or high-level gestures. We avoid doing both because that will
  /// result in double-firing of event listeners, such as `onTap` on a button.
  /// An approach we use is to measure the distance between the last pointer
  /// event and a gesture event. If a gesture is receive "soon" after the last
  /// received pointer event (determined by a heuristic), it is debounced as it
  /// is likely that the gesture detected from the pointer even will do the
  /// right thing. However, if we receive a standalone gesture we will map it
  /// onto a [ui.SemanticsAction] to be processed by the framework.
  void receiveGlobalEvent(html.Event event) {
    // For pointer event reference see:
    //
    // https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events
    const _pointerEventTypes = [
      'pointerdown',
      'pointermove',
      'pointerup',
      'pointercancel',
      'touchstart',
      'touchend',
      'touchmove',
      'touchcancel',
    ];

    if (_pointerEventTypes.contains(event.type)) {
      _temporarilyDisableBrowserGestureMode();
    }
  }

  /// Callbacks called when the [GestureMode] changes.
  ///
  /// Callbacks are called synchronously. HTML DOM updates made in a callback
  /// take effect in the current animation frame and/or the current message loop
  /// event.
  List<GestureModeCallback> _gestureModeListeners = <GestureModeCallback>[];

  /// Calls the [callback] every time the current [GestureMode] changes.
  ///
  /// The callback is called synchronously. HTML DOM updates made in the
  /// callback take effect in the current animation frame and/or the current
  /// message loop event.
  void _addGestureModeListener(GestureModeCallback callback) {
    _gestureModeListeners.add(callback);
  }

  /// Stops calling the [callback] when the [GestureMode] changes.
  ///
  /// The passed [callback] must be the exact same object as the one passed to
  /// [_addGestureModeListener].
  void _removeGestureModeListener(GestureModeCallback callback) {
    assert(_gestureModeListeners.contains(callback));
    _gestureModeListeners.remove(callback);
  }

  void _notifyGestureModeListeners() {
    for (int i = 0; i < _gestureModeListeners.length; i++) {
      _gestureModeListeners[i](_gestureMode);
    }
  }

  /// Whether a gesture event of type [eventType] should be accepted as a
  /// semantic action.
  ///
  /// If [mode] is [AccessibilityMode.known] the gesture is always accepted if
  /// [semanticsEnabled] is `true`, and it is always rejected if
  /// [semanticsEnabled] is `false`.
  ///
  /// If [mode] is [AccessibilityMode.unknown] the gesture is accepted if it is
  /// not accompanied by pointer events. In the presence of pointer events we
  /// delegate to Flutter's gesture detection system to produce gestures.
  bool shouldAcceptBrowserGesture(String eventType) {
    if (_mode == AccessibilityMode.known) {
      // Do not ignore accessibility gestures in known mode, unless semantics
      // is explicitly disabled.
      return semanticsEnabled;
    }

    const List<String> pointerDebouncedGestures = <String>[
      'click',
      'scroll',
    ];

    if (pointerDebouncedGestures.contains(eventType)) {
      return _gestureMode == GestureMode.browserGestures;
    }

    return false;
  }

  /// Looks up a [SemanticsObject] in the semantics tree by ID, or creates a new
  /// instance if it does not exist.
  SemanticsObject getOrCreateObject(int id) {
    SemanticsObject object = _semanticsTree[id];
    if (object == null) {
      object = SemanticsObject(id, this);
      _semanticsTree[id] = object;
    }
    return object;
  }

  /// Updates the semantics tree from data in the [uiUpdate].
  void updateSemantics(ui.SemanticsUpdate uiUpdate) {
    if (!_semanticsEnabled) {
      return;
    }

    SemanticsUpdate update = uiUpdate;
    for (SemanticsNodeUpdate nodeUpdate in update._nodeUpdates) {
      SemanticsObject object = getOrCreateObject(nodeUpdate.id);
      object.updateWith(nodeUpdate);
    }

    if (_rootSemanticsElement == null) {
      final SemanticsObject root = _semanticsTree[0];
      _rootSemanticsElement = root.element;
      html.document.body.append(_rootSemanticsElement);
    }

    _finalizeTree();

    assert(_semanticsTree.containsKey(0)); // must contain root node
    assert(() {
      // Validate tree
      _semanticsTree.forEach((int id, SemanticsObject object) {
        assert(id == object.id);
        // Ensure child ID list is consistent with the parent-child
        // relationship of the semantics tree.
        if (object._childrenInTraversalOrder != null) {
          for (int childId in object._childrenInTraversalOrder) {
            final SemanticsObject child = _semanticsTree[childId];
            if (child == null) {
              throw AssertionError('Child #${childId} is missing in the tree.');
            }
            if (child._parent == null) {
              throw AssertionError(
                  'Child #${childId} of parent #${object.id} has null parent '
                  'reference.');
            }
            if (!identical(child._parent, object)) {
              throw AssertionError(
                  'Parent #${object.id} has child #${childId}. However, the '
                  'child is attached to #${child._parent.id}.');
            }
          }
        }
      });

      // Validate that all updates were applied
      for (SemanticsNodeUpdate update in update._nodeUpdates) {
        // Node was added to the tree.
        assert(_semanticsTree.containsKey(update.id));
        // We created a DOM element for it.
        assert(_semanticsTree[update.id].element != null);
      }

      return true;
    }());
  }
}

/// Computes the [longest increasing subsequence](http://en.wikipedia.org/wiki/Longest_increasing_subsequence).
///
/// Returns list of indices (rather than values) into [list].
///
/// Complexity: n*log(n)
List<int> longestIncreasingSubsequence(List<int> list) {
  final len = list.length;
  final predecessors = <int>[];
  final mins = <int>[0];
  int longest = 0;
  for (int i = 0; i < len; i++) {
    // Binary search for the largest positive `j ≤ longest`
    // such that `list[mins[j]] < list[i]`
    int elem = list[i];
    int lo = 1;
    int hi = longest;
    while (lo <= hi) {
      int mid = (lo + hi) ~/ 2;
      if (list[mins[mid]] < elem) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    // After searching, `lo` is 1 greater than the
    // length of the longest prefix of `list[i]`
    int expansionIndex = lo;
    // The predecessor of `list[i]` is the last index of
    // the subsequence of length `newLongest - 1`
    predecessors.add(mins[expansionIndex - 1]);
    if (expansionIndex >= mins.length) {
      mins.add(i);
    } else {
      mins[expansionIndex] = i;
    }
    if (expansionIndex > longest) {
      // If we found a subsequence longer than any we've
      // found yet, update `longest`
      longest = expansionIndex;
    }
  }
  // Reconstruct the longest subsequence
  final seq = new List<int>(longest);
  int k = mins[longest];
  for (int i = longest - 1; i >= 0; i--) {
    seq[i] = k;
    k = predecessors[k];
  }
  return seq;
}
