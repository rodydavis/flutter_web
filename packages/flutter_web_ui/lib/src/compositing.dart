// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import 'bitmap_canvas.dart';
import 'canvas.dart';
import 'compositor/layer_scene_builder.dart';
import 'dom_canvas.dart';
import 'dom_renderer.dart';
import 'engine_canvas.dart';
import 'geometry.dart';
import 'houdini_canvas.dart';
import 'painting.dart';
import 'shadow.dart';
import 'util.dart';
import 'window.dart';

/// When `true` prints detailed explanations why particular DOM nodes were or
/// were not reused.
const _debugExplainDomReuse = false;

/// The threshold for the canvas pixel count to screen pixel count ratio, beyond
/// which in debug mode a warning is issued to the console.
///
/// As we improve canvas utilization we should decrease this number. It is
/// unlikely that we will hit 1.0, but something around 3.0 should be
/// reasonable.
const _kScreenPixelRatioWarningThreshold = 6.0;

/// An opaque object representing a composited scene.
///
/// To create a Scene object, use a [SceneBuilder].
///
/// Scene objects can be displayed on the screen using the
/// [Window.render] method.
class Scene {
  /// This class is created by the engine, and should not be instantiated
  /// or extended directly.
  ///
  /// To create a Scene object, use a [SceneBuilder].
  Scene._(this.webOnlyRootElement);

  final html.Element webOnlyRootElement;

  /// Creates a raster image representation of the current state of the scene.
  /// This is a slow operation that is performed on a background thread.
  Future<Image> toImage(int width, int height) {
    if (width <= 0 || height <= 0)
      throw new Exception('Invalid image dimensions.');
    throw UnsupportedError('toImage is not supported on the Web');
    // TODO(flutter_web): Implement [_toImage].
    // return futurize(
    //     (Callback<Image> callback) => _toImage(width, height, callback));
  }

  // String _toImage(int width, int height, Callback<Image> callback) => null;

  /// Releases the resources used by this scene.
  ///
  /// After calling this function, the scene is cannot be used further.
  void dispose() {}
}

/// Builds a [Scene] containing the given visuals.
///
/// A [Scene] can then be rendered using [Window.render].
///
/// To draw graphical operations onto a [Scene], first create a
/// [Picture] using a [PictureRecorder] and a [Canvas], and then add
/// it to the scene using [addPicture].
class SceneBuilder {
  static const webOnlyUseLayerSceneBuilder = false;

  /// Creates an empty [SceneBuilder] object.
  factory SceneBuilder() {
    if (webOnlyUseLayerSceneBuilder) {
      return LayerSceneBuilder();
    } else {
      return SceneBuilder._();
    }
  }
  SceneBuilder._() {
    _surfaceStack.add(_PersistedScene());
  }

  factory SceneBuilder.layer() = LayerSceneBuilder;

  final List<_PersistedContainerSurface> _surfaceStack =
      <_PersistedContainerSurface>[];

  /// The scene built by this scene builder.
  ///
  /// This getter should only be called after all surfaces are built.
  _PersistedScene get _persistedScene {
    assert(() {
      if (_surfaceStack.length != 1) {
        final surfacePrintout =
            _surfaceStack.map((l) => l.runtimeType).toList().join(', ');
        throw Exception('Incorrect sequence of push/pop operations while '
            'building scene surfaces. After building the scene the persisted '
            'surface stack must contain a single element which corresponds '
            'to the scene itself (_PersistedScene). All other surfaces '
            'should have been popped off the stack. Found the following '
            'surfaces in the stack:\n${surfacePrintout}');
      }
      return true;
    }());
    return _surfaceStack.first;
  }

  /// The surface currently being built.
  _PersistedContainerSurface get _currentSurface => _surfaceStack.last;

  void _pushSurface(_PersistedContainerSurface surface) {
    _adoptSurface(surface);
    _surfaceStack.add(surface);
  }

  void _addSurface(_PersistedLeafSurface surface) {
    _adoptSurface(surface);
  }

  void _adoptSurface(_PersistedSurface surface) {
    _currentSurface.appendChild(surface);
  }

  /// Pushes an offset operation onto the operation stack.
  ///
  /// This is equivalent to [pushTransform] with a matrix with only translation.
  ///
  /// See [pop] for details about the operation stack.
  EngineLayer pushOffset(double dx, double dy,
      {@required Object webOnlyPaintedBy}) {
    _pushSurface(_PersistedOffset(webOnlyPaintedBy, dx, dy));
    return null; // this does not return an engine layer yet.
  }

  /// Pushes a transform operation onto the operation stack.
  ///
  /// The objects are transformed by the given matrix before rasterization.
  ///
  /// See [pop] for details about the operation stack.
  void pushTransform(Float64List matrix4, {@required Object webOnlyPaintedBy}) {
    if (matrix4 == null)
      throw new ArgumentError('"matrix4" argument cannot be null');
    if (matrix4.length != 16)
      throw new ArgumentError('"matrix4" must have 16 entries.');
    _pushTransform(matrix4, webOnlyPaintedBy);
  }

  void _pushTransform(Float64List matrix4, Object webOnlyPaintedBy) {
    _pushSurface(_PersistedTransform(webOnlyPaintedBy, matrix4));
  }

  /// Pushes a rectangular clip operation onto the operation stack.
  ///
  /// Rasterization outside the given rectangle is discarded.
  ///
  /// See [pop] for details about the operation stack, and [Clip] for different clip modes.
  /// By default, the clip will be anti-aliased (clip = [Clip.antiAlias]).
  void pushClipRect(Rect rect,
      {Clip clipBehavior = Clip.antiAlias, @required Object webOnlyPaintedBy}) {
    assert(clipBehavior != null);
    assert(clipBehavior != Clip.none);
    _pushSurface(_PersistedClipRect(webOnlyPaintedBy, rect));
  }

  /// Pushes a rounded-rectangular clip operation onto the operation stack.
  ///
  /// Rasterization outside the given rounded rectangle is discarded.
  ///
  /// See [pop] for details about the operation stack.
  void pushClipRRect(RRect rrect,
      {Clip clipBehavior, @required Object webOnlyPaintedBy}) {
    _pushSurface(_PersistedClipRRect(webOnlyPaintedBy, rrect, clipBehavior));
  }

  /// Pushes a path clip operation onto the operation stack.
  ///
  /// Rasterization outside the given path is discarded.
  ///
  /// See [pop] for details about the operation stack.
  void pushClipPath(Path path,
      {Clip clipBehavior = Clip.antiAlias, @required Object webOnlyPaintedBy}) {
    assert(clipBehavior != null);
    assert(clipBehavior != Clip.none);
    throw UnimplementedError();
  }

  /// Pushes an opacity operation onto the operation stack.
  ///
  /// The given alpha value is blended into the alpha value of the objects'
  /// rasterization. An alpha value of 0 makes the objects entirely invisible.
  /// An alpha value of 255 has no effect (i.e., the objects retain the current
  /// opacity).
  ///
  /// See [pop] for details about the operation stack.
  void pushOpacity(int alpha,
      {@required Object webOnlyPaintedBy, Offset offset = Offset.zero}) {
    _pushSurface(_PersistedOpacity(webOnlyPaintedBy, alpha, offset));
  }

  /// Pushes a color filter operation onto the operation stack.
  ///
  /// The given color is applied to the objects' rasterization using the given
  /// blend mode.
  ///
  /// See [pop] for details about the operation stack.
  void pushColorFilter(Color color, BlendMode blendMode,
      {@required Object webOnlyPaintedBy}) {
    _pushColorFilter(color.value, blendMode.index, webOnlyPaintedBy);
  }

  void _pushColorFilter(int color, int blendMode, Object webOnlyPaintedBy) {
    throw new UnimplementedError();
  }

  /// Pushes a backdrop filter operation onto the operation stack.
  ///
  /// The given filter is applied to the current contents of the scene prior to
  /// rasterizing the given objects.
  ///
  /// See [pop] for details about the operation stack.
  void pushBackdropFilter(ImageFilter filter,
      {@required Object webOnlyPaintedBy}) {
    throw new UnimplementedError();
  }

  /// Pushes a shader mask operation onto the operation stack.
  ///
  /// The given shader is applied to the object's rasterization in the given
  /// rectangle using the given blend mode.
  ///
  /// See [pop] for details about the operation stack.
  void pushShaderMask(Shader shader, Rect maskRect, BlendMode blendMode,
      {@required Object webOnlyPaintedBy}) {
    _pushShaderMask(shader, maskRect.left, maskRect.right, maskRect.top,
        maskRect.bottom, blendMode.index, webOnlyPaintedBy);
  }

  void _pushShaderMask(
      Shader shader,
      double maskRectLeft,
      double maskRectRight,
      double maskRectTop,
      double maskRectBottom,
      int blendMode,
      Object webOnlyPaintedBy) {
    throw new UnimplementedError();
  }

  /// Pushes a physical layer operation for an arbitrary shape onto the
  /// operation stack.
  ///
  /// By default, the layer's content will not be clipped (clip = [Clip.none]).
  /// If clip equals [Clip.hardEdge], [Clip.antiAlias], or [Clip.antiAliasWithSaveLayer],
  /// then the content is clipped to the given shape defined by [path].
  ///
  /// If [elevation] is greater than 0.0, then a shadow is drawn around the layer.
  /// [shadowColor] defines the color of the shadow if present and [color] defines the
  /// color of the layer background.
  ///
  /// See [pop] for details about the operation stack, and [Clip] for different clip modes.
  EngineLayer pushPhysicalShape({
    Path path,
    double elevation,
    Color color,
    Color shadowColor,
    Clip clipBehavior = Clip.none,
    @required Object webOnlyPaintedBy,
  }) {
    _pushPhysicalShape(path, elevation, color.value,
        shadowColor?.value ?? 0xFF000000, clipBehavior, webOnlyPaintedBy);
    return null; // this does not return an engine layer yet.
  }

  void _pushPhysicalShape(Path path, double elevation, int color,
      int shadowColor, Clip clipBehavior, Object webOnlyPaintedBy) {
    _pushSurface(_PersistedPhysicalShape(
        webOnlyPaintedBy, path, elevation, color, shadowColor, clipBehavior));
  }

  void addRetained(EngineLayer retainedLayer) {
    throw UnimplementedError('SceneBuilder.addRetained not implemented');
  }

  /// Ends the effect of the most recently pushed operation.
  ///
  /// Internally the scene builder maintains a stack of operations. Each of the
  /// operations in the stack applies to each of the objects added to the scene.
  /// Calling this function removes the most recently added operation from the
  /// stack.
  void pop() {
    assert(_surfaceStack.isNotEmpty);
    _surfaceStack.removeLast();
  }

  /// Adds an object to the scene that displays performance statistics.
  ///
  /// Useful during development to assess the performance of the application.
  /// The enabledOptions controls which statistics are displayed. The bounds
  /// controls where the statistics are displayed.
  ///
  /// enabledOptions is a bit field with the following bits defined:
  ///  - 0x01: displayRasterizerStatistics - show GPU thread frame time
  ///  - 0x02: visualizeRasterizerStatistics - graph GPU thread frame times
  ///  - 0x04: displayEngineStatistics - show UI thread frame time
  ///  - 0x08: visualizeEngineStatistics - graph UI thread frame times
  /// Set enabledOptions to 0x0F to enable all the currently defined features.
  ///
  /// The "UI thread" is the thread that includes all the execution of
  /// the main Dart isolate (the isolate that can call
  /// [Window.render]). The UI thread frame time is the total time
  /// spent executing the [Window.onBeginFrame] callback. The "GPU
  /// thread" is the thread (running on the CPU) that subsequently
  /// processes the [Scene] provided by the Dart code to turn it into
  /// GPU commands and send it to the GPU.
  ///
  /// See also the [PerformanceOverlayOption] enum in the rendering library.
  /// for more details.
  void addPerformanceOverlay(int enabledOptions, Rect bounds,
      {@required Object webOnlyPaintedBy}) {
    _addPerformanceOverlay(enabledOptions, bounds.left, bounds.right,
        bounds.top, bounds.bottom, webOnlyPaintedBy);
  }

  void _addPerformanceOverlay(int enabledOptions, double left, double right,
      double top, double bottom, Object webOnlyPaintedBy) {
    throw new UnimplementedError();
  }

  /// Adds a [Picture] to the scene.
  ///
  /// The picture is rasterized at the given offset.
  void addPicture(Offset offset, Picture picture,
      {bool isComplexHint = false,
      bool willChangeHint = false,
      @required Object webOnlyPaintedBy}) {
    int hints = 0;
    if (isComplexHint) hints |= 1;
    if (willChangeHint) hints |= 2;
    _addPicture(offset.dx, offset.dy, picture, hints,
        webOnlyPaintedBy: webOnlyPaintedBy);
  }

  void _addPicture(double dx, double dy, Picture picture, int hints,
      {@required Object webOnlyPaintedBy}) {
    _addSurface(
        persistedPictureFactory(webOnlyPaintedBy, dx, dy, picture, hints));
  }

  /// Adds a backend texture to the scene.
  ///
  /// The texture is scaled to the given size and rasterized at the given
  /// offset.
  void addTexture(int textureId,
      {Offset offset = Offset.zero,
      double width = 0.0,
      double height = 0.0,
      bool freeze = false,
      @required Object webOnlyPaintedBy}) {
    assert(offset != null, 'Offset argument was null');
    _addTexture(
        offset.dx, offset.dy, width, height, textureId, webOnlyPaintedBy);
  }

  void _addTexture(double dx, double dy, double width, double height,
      int textureId, Object webOnlyPaintedBy) {
    throw new UnimplementedError();
  }

  /// Adds a platform view (e.g an iOS UIView) to the scene.
  ///
  /// Only supported on iOS, this is currently a no-op on other platforms.
  ///
  /// On iOS this layer splits the current output surface into two surfaces, one for the scene nodes
  /// preceding the platform view, and one for the scene nodes following the platform view.
  ///
  /// ## Performance impact
  ///
  /// Adding an additional surface doubles the amount of graphics memory directly used by Flutter
  /// for output buffers. Quartz might allocated extra buffers for compositing the Flutter surfaces
  /// and the platform view.
  ///
  /// With a platform view in the scene, Quartz has to composite the two Flutter surfaces and the
  /// embedded UIView. In addition to that, on iOS versions greater than 9, the Flutter frames are
  /// synchronized with the UIView frames adding additional performance overhead.
  void addPlatformView(int viewId,
      {Offset offset: Offset.zero, double width: 0.0, double height: 0.0}) {
    assert(offset != null, 'Offset argument was null');
    _addPlatformView(offset.dx, offset.dy, width, height, viewId);
  }

  void _addPlatformView(
      double dx, double dy, double width, double height, int viewId) {
    throw new UnimplementedError();
  }

  /// (Fuchsia-only) Adds a scene rendered by another application to the scene
  /// for this application.
  void addChildScene(
      {Offset offset = Offset.zero,
      double width = 0.0,
      double height = 0.0,
      SceneHost sceneHost,
      bool hitTestable = true}) {
    _addChildScene(offset.dx, offset.dy, width, height, sceneHost, hitTestable);
  }

  void _addChildScene(double dx, double dy, double width, double height,
      SceneHost sceneHost, bool hitTestable) {
    throw new UnimplementedError();
  }

  /// Sets a threshold after which additional debugging information should be
  /// recorded.
  ///
  /// Currently this interface is difficult to use by end-developers. If you're
  /// interested in using this feature, please contact [flutter-dev](https://groups.google.com/forum/#!forum/flutter-dev).
  /// We'll hopefully be able to figure out how to make this feature more useful
  /// to you.
  void setRasterizerTracingThreshold(int frameInterval) {}

  /// Sets whether the raster cache should checkerboard cached entries. This is
  /// only useful for debugging purposes.
  ///
  /// The compositor can sometimes decide to cache certain portions of the
  /// widget hierarchy. Such portions typically don't change often from frame to
  /// frame and are expensive to render. This can speed up overall rendering.
  /// However, there is certain upfront cost to constructing these cache
  /// entries. And, if the cache entries are not used very often, this cost may
  /// not be worth the speedup in rendering of subsequent frames. If the
  /// developer wants to be certain that populating the raster cache is not
  /// causing stutters, this option can be set. Depending on the observations
  /// made, hints can be provided to the compositor that aid it in making better
  /// decisions about caching.
  ///
  /// Currently this interface is difficult to use by end-developers. If you're
  /// interested in using this feature, please contact [flutter-dev](https://groups.google.com/forum/#!forum/flutter-dev).
  void setCheckerboardRasterCacheImages(bool checkerboard) {}

  /// Sets whether the compositor should checkerboard layers that are rendered
  /// to offscreen bitmaps.
  ///
  /// This is only useful for debugging purposes.
  void setCheckerboardOffscreenLayers(bool checkerboard) {}

  /// The scene recorded in the last frame.
  ///
  /// This is a surface tree that holds onto the DOM elements that can be reused
  /// on the next frame.
  static _PersistedScene _lastFrameScene;

  static int _debugFrameNumber = 0;

  /// Finishes building the scene.
  ///
  /// Returns a [Scene] containing the objects that have been added to
  /// this scene builder. The [Scene] can then be displayed on the
  /// screen with [Window.render].
  ///
  /// After calling this function, the scene builder object is invalid and
  /// cannot be used further.
  Scene build() {
    assert(() {
      _debugFrameNumber++;
      return true;
    }());
    if (_lastFrameScene == null) {
      _persistedScene.build();
    } else {
      _persistedScene.update(_lastFrameScene);
    }
    if (_paintQueue.isNotEmpty) {
      for (VoidCallback paintCallback in _paintQueue) {
        paintCallback();
      }
      _paintQueue = <VoidCallback>[];
    }
    if (assertionsEnabled || _debugExplainDomReuse) {
      _debugPrintReuseStats(_persistedScene, _debugFrameNumber);
    }
    assert(() {
      final validationErrors = <String>[];
      _persistedScene.debugValidate(validationErrors);
      if (validationErrors.isNotEmpty) {
        print('ENGINE LAYER TREE INCONSISTENT:\n'
            '${validationErrors.map((e) => '  - $e\n').join()}');
      }
      return true;
    }());
    _lastFrameScene = _persistedScene;
    return new Scene._(_persistedScene.rootElement);
  }
}

void _debugPrintReuseStats(_PersistedScene scene, int frameNumber) {
  int canvasCount = 0;
  int canvasReuseCount = 0;
  int canvasAllocationCount = 0;
  int canvasPaintSkipCount = 0;
  int elementReuseCount = 0;
  void countReusesRecursively(_PersistedSurface surface) {
    elementReuseCount += surface._debugDidReuseElement ? 1 : 0;
    if (surface is _PersistedStandardPicture) {
      canvasCount += 1;
      canvasReuseCount += surface._debugDidReuseCanvas ? 1 : 0;
      canvasAllocationCount += surface._debugDidAllocateNewCanvas ? 1 : 0;
      canvasPaintSkipCount += surface._debugDidNotPaint ? 1 : 0;
    }
    surface.visitChildren(countReusesRecursively);
  }

  scene.visitChildren(countReusesRecursively);

  final StringBuffer buf = StringBuffer();
  buf
    ..writeln(
        '---------------------- FRAME #${frameNumber} -------------------------')
    ..writeln('Elements reused: $elementReuseCount')
    ..writeln('Canvases:')
    ..writeln('  Active: ${canvasCount}')
    ..writeln('  Reused: $canvasReuseCount')
    ..writeln('  Allocated: $canvasAllocationCount')
    ..writeln('  Skipped painting: $canvasPaintSkipCount')
    ..writeln('  Available for reuse: ${_recycledCanvases.length}');

  // A microtask will fire after the DOM is flushed, letting us probe into
  // actual <canvas> tags.
  scheduleMicrotask(() {
    final canvasElements = html.document.querySelectorAll('canvas');
    final StringBuffer canvasInfo = StringBuffer();
    final int pixelCount = canvasElements
        .cast<html.CanvasElement>()
        .map<int>((html.CanvasElement e) {
      final int pixels = e.width * e.height;
      canvasInfo.writeln('    - ${e.width} x ${e.height} = ${pixels} pixels');
      return pixels;
    }).fold(0, (int total, int pixels) => total + pixels);
    final double physicalScreenWidth =
        html.window.innerWidth * html.window.devicePixelRatio;
    final double physicalScreenHeight =
        html.window.innerHeight * html.window.devicePixelRatio;
    final double physicsScreenPixelCount =
        physicalScreenWidth * physicalScreenHeight;
    final double screenPixelRatio = pixelCount / physicsScreenPixelCount;
    final String screenDescription =
        '1 screen is ${physicalScreenWidth} x ${physicalScreenHeight} = ${physicsScreenPixelCount} pixels';
    final String canvasPixelDescription =
        '${pixelCount} (${screenPixelRatio.toStringAsFixed(2)} x screens';
    buf
      ..writeln('  Elements: ${canvasElements.length}')
      ..writeln(canvasInfo)
      ..writeln('  Pixels: $canvasPixelDescription; $screenDescription)')
      ..writeln('-----------------------------------------------------------');
    bool screenPixelRatioTooHigh =
        screenPixelRatio > _kScreenPixelRatioWarningThreshold;
    if (screenPixelRatioTooHigh) {
      print(
          'WARNING: pixel/screen ratio too high (${screenPixelRatio.toStringAsFixed(2)}x)');
    }
    if (screenPixelRatioTooHigh || _debugExplainDomReuse) {
      print(buf);
    }
  });
}

/// (Fuchsia-only) Hosts content provided by another application.
class SceneHost {
  /// Creates a host for a child scene.
  ///
  /// The export token is bound to a scene graph node which acts as a container
  /// for the child's content.  The creator of the scene host is responsible for
  /// sending the corresponding import token (the other endpoint of the event
  /// pair) to the child.
  ///
  /// The export token is a dart:zircon Handle, but that type isn't
  /// available here. This is called by ChildViewConnection in
  /// //topaz/public/lib/ui/flutter/.
  ///
  /// The scene host takes ownership of the provided export token handle.
  SceneHost(dynamic exportTokenHandle);

  /// Releases the resources associated with the child scene host.
  ///
  /// After calling this function, the child scene host cannot be used further.
  void dispose() {}
}

typedef _PersistedSurfaceVisitor = void Function(_PersistedSurface);

/// A node in the tree built by [SceneBuilder] that contains information used to
/// compute the fewest amount of mutations necessary to update the browser DOM.
abstract class _PersistedSurface {
  /// Creates a persisted surface.
  ///
  /// [paintedBy] points to the object that painted this surface.
  _PersistedSurface(this.paintedBy) : assert(paintedBy != null);

  /// The root element that renders this surface to the DOM.
  ///
  /// This element can be reused across frames. See also, [childContainer],
  /// which is the element used to manage child nodes.
  html.Element rootElement;

  /// The element that contains child surface elements.
  ///
  /// By default this is the same as the [rootElement]. However, specialized
  /// surface implementations may choose to override this and provide a
  /// different element for nesting children.
  html.Element get childContainer => rootElement;

  /// This surface's immediate parent.
  _PersistedContainerSurface parent;

  /// The render object that painted this surface.
  ///
  /// Used to find a surface in the previous frame whose [element] can be
  /// reused.
  final Object paintedBy;

  /// Render objects that painted something in the subtree rooted at this node.
  ///
  /// Used to find a surface in the previous frame whose [element] can be
  /// reused.
  // TODO(yjbanov): consider benchmarking and potentially using a list that
  //                compiles to JSArray. We may never have duplicates here by
  //                construction. The only other use-case for Set is to perform
  //                an order-agnostic comparison.
  Set<Object> _descendants;

  /// Whether this surface reused an HTML element from a previously rendered
  /// surface.
  bool _debugDidReuseElement = false;

  /// Visits immediate children.
  ///
  /// Does not recurse.
  @protected
  void visitChildren(_PersistedSurfaceVisitor visitor);

  /// Creates a new element and sets the necessary HTML and CSS attributes.
  ///
  /// This is called when we failed to locate an existing DOM element to reuse,
  /// such as on the very first frame.
  @protected
  @mustCallSuper
  void build() {
    rootElement = createElement();
    apply();
  }

  /// Instructs this surface to adopt HTML DOM elements of another surface.
  ///
  /// This is done for efficiency. Instead of creating new DOM elements on every
  /// frame, we reuse old ones as much as possible. This method should only be
  /// called when [isTotalMatchFor] returns true for the [oldSurface]. Otherwise
  /// adopting the [oldSurface]'s elements could lead to correctness issues.
  @protected
  @mustCallSuper
  void adoptElements(covariant _PersistedSurface oldSurface) {
    rootElement = oldSurface.rootElement;
    _debugDidReuseElement = true;
  }

  /// Updates the attributes of this surface's element.
  ///
  /// Attempts to reuse [oldSurface]'s DOM element, if possible. Otherwise,
  /// creates a new element by calling [build].
  @protected
  @mustCallSuper
  void update(covariant _PersistedSurface oldSurface) {
    assert(oldSurface != null);

    if (isTotalMatchFor(oldSurface)) {
      adoptElements(oldSurface);
    } else {
      build();
    }

    // We took ownership of the old element.
    oldSurface.rootElement = null;
    assert(rootElement != null);
  }

  /// Removes the [element] of this surface from the tree.
  ///
  /// This method may be overridden by concrete implementations, for example, to
  /// recycle the resources owned by this surface.
  @protected
  @mustCallSuper
  void recycle() {
    rootElement.remove();
    rootElement = null;
  }

  @protected
  @mustCallSuper
  void debugValidate(List<String> validationErrors) {
    if (rootElement == null) {
      validationErrors.add('$runtimeType has null element.');
    }
  }

  /// A total match between two surfaces is when they are of the same type, were
  /// painted by the same render object, and contain the same set of
  /// descendants.
  // TODO(yjbanov): we should also consider using fuzzy match, e.g. when
  //                descendants shift around but the element is still reusable.
  //                We'd need a more robust disambiguation strategy to implement
  //                this correctly.
  bool isTotalMatchFor(_PersistedSurface other) {
    assert(other != null);
    return other.runtimeType == runtimeType &&
        identical(other.paintedBy, paintedBy) &&
        _hasExactDescendants(other);
  }

  bool _hasExactDescendants(_PersistedSurface other) {
    if ((_descendants == null || _descendants.isEmpty) &&
        (other._descendants == null || other._descendants.isEmpty)) {
      return true;
    } else if (_descendants == null || other._descendants == null) {
      return false;
    }

    if (_descendants.length != other._descendants.length) {
      return false;
    }

    return _descendants.containsAll(other._descendants);
  }

  /// Creates a DOM element for this surface.
  html.Element createElement();

  /// Creates a DOM element for this surface preconfigured with common
  /// attributes, such as absolute positioning and debug information.
  html.Element defaultCreateElement(String tagName) {
    final element = html.Element.tag(tagName);
    element.style.position = 'absolute';
    if (assertionsEnabled) {
      element.setAttribute(
        'created-by',
        '${this.paintedBy.runtimeType}',
      );
    }
    return element;
  }

  /// Sets the HTML and CSS properties appropriate for this surface's
  /// implementation.
  ///
  /// For example, [_PersistedTransform] sets the "transform" CSS attribute.
  void apply();

  /// Prints this surface into a [buffer] in a human-readable format.
  void debugPrint(StringBuffer buffer, int indent) {
    if (rootElement != null) {
      buffer.write('${'  ' * indent}<${rootElement.tagName.toLowerCase()} ');
    } else {
      buffer.write('${'  ' * indent}<$runtimeType recycled ');
    }
    debugPrintAttributes(buffer);
    buffer.writeln('>');
    debugPrintChildren(buffer, indent);
    if (rootElement != null) {
      buffer.writeln('${'  ' * indent}</${rootElement.tagName.toLowerCase()}>');
    } else {
      buffer.writeln('${'  ' * indent}</$runtimeType>');
    }
  }

  @protected
  @mustCallSuper
  void debugPrintAttributes(StringBuffer buffer) {
    if (rootElement != null) {
      buffer.write('@${rootElement.hashCode} ');
    }
    buffer.write('painted-by="${paintedBy.runtimeType}"');
  }

  @protected
  @mustCallSuper
  void debugPrintChildren(StringBuffer buffer, int indent) {}

  @override
  String toString() {
    if (assertionsEnabled) {
      final log = StringBuffer();
      debugPrint(log, 0);
      return log.toString();
    } else {
      return super.toString();
    }
  }
}

/// A surface that doesn't have child surfaces.
abstract class _PersistedLeafSurface extends _PersistedSurface {
  _PersistedLeafSurface(Object paintedBy) : super(paintedBy);

  @override
  void visitChildren(_PersistedSurfaceVisitor visitor) {
    // Does not have children.
  }
}

/// A surface that has a flat list of child surfaces.
abstract class _PersistedContainerSurface extends _PersistedSurface {
  _PersistedContainerSurface(Object paintedBy) : super(paintedBy);

  final List<_PersistedSurface> _children = <_PersistedSurface>[];

  @override
  void visitChildren(_PersistedSurfaceVisitor visitor) {
    _children.forEach(visitor);
  }

  void appendChild(_PersistedSurface child) {
    _children.add(child);
    child.parent = this;

    // Add the child to the list of descendants in all ancestors within the
    // current render object.
    //
    // We only reuse a DOM node when it is painted by the same RenderObject,
    // therefore we need to mark this surface and ancestors within the current
    // render object as having this child as a descendant. This allows us to
    // detect when children move within their list of siblings and reuse their
    // elements.
    if (!identical(child.paintedBy, paintedBy)) {
      _PersistedSurface container = this;
      while (container != null && identical(container.paintedBy, paintedBy)) {
        container._descendants ??= Set<Object>();
        container._descendants.add(child.paintedBy);
        container = container.parent;
      }
    }
  }

  @override
  void build() {
    super.build();
    // Memoize length for efficiency.
    final len = _children.length;
    // Memoize container element for efficiency. [childContainer] is polymorphic
    final html.Element containerElement = childContainer;
    for (int i = 0; i < len; i++) {
      final _PersistedSurface child = _children[i];
      child.build();
      containerElement.append(child.rootElement);
    }
  }

  void _updateChild(_PersistedSurface newChild, _PersistedSurface oldChild) {
    assert(newChild.rootElement == null);
    assert(oldChild.isTotalMatchFor(newChild));
    final html.Element oldElement = oldChild.rootElement;
    assert(oldElement != null);
    newChild.update(oldChild);
    // When the new surface reuses an existing element it takes ownership of it
    // so we null it out in the old surface. This prevents the element from
    // being reused more than once, which would be a serious bug.
    assert(oldChild.rootElement == null);
    assert(identical(newChild.rootElement, oldElement));
  }

  @override
  void update(_PersistedContainerSurface oldContainer) {
    super.update(oldContainer);

    // A simple algorithms that attempts to reuse DOM elements from the previous
    // frame:
    //
    // - Scans both the old list and the new list in reverse, updating matching
    //   child surfaces. The reason for iterating in reverse is so that we can
    //   move the child in a single call to `insertBefore`. Otherwise, we'd have
    //   to do a more complicated dance of finding the next sibling and special
    //   casing `append`.
    // - If non-match is found, performs a search (also in reverse) to locate a
    //   reusable element, then moves it towards the back.
    // - If no reusable element is found, creates a new one.

    int bottomInNew = _children.length - 1;
    int bottomInOld = oldContainer._children.length - 1;

    // Memoize container element for efficiency. [childContainer] is polymorphic
    final html.Element containerElement = childContainer;

    while (bottomInNew >= 0 && bottomInOld >= 0) {
      final newChild = _children[bottomInNew];
      if (oldContainer._children[bottomInOld].isTotalMatchFor(newChild)) {
        _updateChild(newChild, oldContainer._children[bottomInOld]);
        bottomInOld--;
      } else {
        // Scan back for a matching old child, if any.
        int searchPointer = bottomInOld - 1;
        _PersistedSurface match;

        // Searching by scanning the array backwards may seem inefficient, but
        // in practice we'll have single-digit child lists. It is better to scan
        // and not perform any allocations than utilize fancier data structures
        // (e.g. maps).
        while (searchPointer >= 0) {
          final candidate = oldContainer._children[searchPointer];
          final isNotYetReused = candidate.rootElement != null;
          if (isNotYetReused && candidate.isTotalMatchFor(newChild)) {
            match = candidate;
            break;
          }
          searchPointer--;
        }

        // If we found a match, reuse the element. Otherwise, create a new one.
        if (match != null) {
          _updateChild(newChild, match);
        } else {
          newChild.build();
        }

        if (bottomInNew + 1 < _children.length) {
          final nextSibling = _children[bottomInNew + 1];
          containerElement.insertBefore(
              newChild.rootElement, nextSibling.rootElement);
        } else {
          containerElement.append(newChild.rootElement);
        }
      }
      assert(newChild.rootElement != null);
      bottomInNew--;
    }

    while (bottomInNew >= 0) {
      // We scanned the old container and attempted to reuse as much as possible
      // but there are still elements in the new list that need to be updated.
      // Since there are no more old elements to reuse, we build new ones.
      assert(bottomInOld == -1);
      final newChild = _children[bottomInNew];
      newChild.build();

      if (bottomInNew + 1 < _children.length) {
        final nextSibling = _children[bottomInNew + 1];
        containerElement.insertBefore(
            newChild.rootElement, nextSibling.rootElement);
      } else {
        containerElement.append(newChild.rootElement);
      }
      bottomInNew--;
      assert(newChild.rootElement != null);
    }

    // Remove elements that were not reused this frame.
    final len = oldContainer._children.length;
    for (int i = 0; i < len; i++) {
      _PersistedSurface oldChild = oldContainer._children[i];
      if (oldChild.rootElement != null) {
        oldChild.recycle();
      }
    }

    // At the end of this all children should have an element each, and it
    // should be attached to this container's element.
    assert(() {
      for (int i = 0; i < oldContainer._children.length; i++) {
        assert(oldContainer._children[i].rootElement == null);
        assert(oldContainer._children[i].childContainer == null);
      }
      for (int i = 0; i < _children.length; i++) {
        assert(_children[i].rootElement != null);
        assert(_children[i].rootElement.parent == containerElement);
      }
      return true;
    }());
  }

  @override
  void recycle() {
    for (int i = 0; i < _children.length; i++) {
      _children[i].recycle();
    }
    super.recycle();
  }

  @protected
  @mustCallSuper
  void debugValidate(List<String> validationErrors) {
    super.debugValidate(validationErrors);
    for (int i = 0; i < _children.length; i++) {
      _children[i].debugValidate(validationErrors);
    }
  }

  @override
  void debugPrintChildren(StringBuffer buffer, int indent) {
    super.debugPrintChildren(buffer, indent);
    for (int i = 0; i < _children.length; i++) {
      _children[i].debugPrint(buffer, indent + 1);
    }
  }
}

/// A surface that creates a DOM element for whole app.
class _PersistedScene extends _PersistedContainerSurface {
  _PersistedScene() : super(const Object());

  @override
  html.Element createElement() {
    final html.Element element = defaultCreateElement('flt-scene');

    // Hide the DOM nodes used to render the scene from accessibility, because
    // the accessibility tree is built from the SemanticsNode tree as a parallel
    // DOM tree.
    domRenderer.setElementAttribute(element, 'aria-hidden', 'true');
    return element;
  }

  @override
  void apply() {}
}

/// A surface that transforms its children using CSS transform.
class _PersistedTransform extends _PersistedContainerSurface {
  _PersistedTransform(Object paintedBy, this.matrix4) : super(paintedBy);

  final Float64List matrix4;

  @override
  html.Element createElement() {
    return defaultCreateElement('flt-transform')
      ..style.transformOrigin = '0 0 0';
  }

  @override
  void apply() {
    rootElement.style.transform = float64ListToCssTransform(matrix4);
  }

  @override
  void update(_PersistedTransform oldSurface) {
    super.update(oldSurface);

    if (identical(oldSurface.matrix4, matrix4)) {
      return;
    }

    bool matrixChanged = false;
    for (int i = 0; i < matrix4.length; i++) {
      if (matrix4[i] != oldSurface.matrix4[i]) {
        matrixChanged = true;
        break;
      }
    }

    if (matrixChanged) {
      apply();
    }
  }
}

/// A surface that translates its children using CSS transform and translate.
class _PersistedOffset extends _PersistedContainerSurface {
  _PersistedOffset(Object paintedBy, this.dx, this.dy) : super(paintedBy);

  /// Horizontal displacement.
  final double dx;

  /// Vertical displacement.
  final double dy;

  @override
  html.Element createElement() {
    return defaultCreateElement('flt-offset')..style.transformOrigin = '0 0 0';
  }

  @override
  void apply() {
    rootElement.style.transform = 'translate(${dx}px, ${dy}px)';
  }

  @override
  void update(_PersistedOffset oldSurface) {
    super.update(oldSurface);

    if (oldSurface.dx != dx || oldSurface.dy != dy) {
      apply();
    }
  }
}

/// Mixin used by surfaces that clip their contents using an overflowing DOM
/// element.
mixin _DomClip on _PersistedContainerSurface {
  /// The dedicated child container element that's separate from the
  /// [rootElement] is used to compensate for the coordinate system shift
  /// introduced by the [rootElement] translation.
  @override
  html.Element get childContainer => _childContainer;
  html.Element _childContainer;

  @override
  void adoptElements(_DomClip oldSurface) {
    super.adoptElements(oldSurface);
    _childContainer = oldSurface._childContainer;
    oldSurface._childContainer = null;
  }

  @override
  html.Element createElement() {
    final html.Element element = defaultCreateElement('flt-clip');
    element.style.overflow = 'hidden';
    _childContainer = html.Element.tag('flt-clip-interior');
    _childContainer.style.position = 'absolute';
    element.append(_childContainer);
    return element;
  }

  @override
  void recycle() {
    super.recycle();

    // Do not detach the child container from the root. It is permanently
    // attached. The elements are reused together and are detached from the DOM
    // together.
    _childContainer = null;
  }
}

/// A surface that creates a rectangular clip.
class _PersistedClipRect extends _PersistedContainerSurface with _DomClip {
  _PersistedClipRect(Object paintedBy, this.rect) : super(paintedBy);

  final Rect rect;

  @override
  html.Element createElement() {
    return super.createElement()..setAttribute('clip-type', 'rect');
  }

  @override
  void apply() {
    rootElement.style
      ..transform = 'translate(${rect.left}px, ${rect.top}px)'
      ..width = '${rect.right - rect.left}px'
      ..height = '${rect.bottom - rect.top}px';

    // Translate the child container in the opposite direction to compensate for
    // the shift in the coordinate system introduced by the translation of the
    // rootElement. Clipping in Flutter has no effect on the coordinate system.
    childContainer.style.transform =
        'translate(${-rect.left}px, ${-rect.top}px)';
  }

  @override
  void update(_PersistedClipRect oldSurface) {
    super.update(oldSurface);
    if (rect != oldSurface.rect) {
      apply();
    }
  }
}

/// A surface that creates a rounded rectangular clip.
class _PersistedClipRRect extends _PersistedContainerSurface with _DomClip {
  _PersistedClipRRect(Object paintedBy, this.rrect, this.clipBehavior)
      : super(paintedBy);

  final RRect rrect;
  // TODO(yjbanov): can this be controlled in the browser?
  final Clip clipBehavior;

  @override
  html.Element createElement() {
    return super.createElement()..setAttribute('clip-type', 'rrect');
  }

  @override
  void apply() {
    rootElement.style
      ..transform = 'translate(${rrect.left}px, ${rrect.top}px)'
      ..width = '${rrect.width}px'
      ..height = '${rrect.height}px'
      ..borderTopLeftRadius = '${rrect.tlRadiusX}px'
      ..borderTopRightRadius = '${rrect.trRadiusX}px'
      ..borderBottomRightRadius = '${rrect.brRadiusX}px'
      ..borderBottomLeftRadius = '${rrect.blRadiusX}px';

    // Translate the child container in the opposite direction to compensate for
    // the shift in the coordinate system introduced by the translation of the
    // rootElement. Clipping in Flutter has no effect on the coordinate system.
    childContainer.style.transform =
        'translate(${-rrect.left}px, ${-rrect.top}px)';
  }

  @override
  void update(_PersistedClipRRect oldSurface) {
    super.update(oldSurface);
    if (rrect != oldSurface.rrect) {
      apply();
    }
  }
}

/// A surface that makes its children transparent.
class _PersistedOpacity extends _PersistedContainerSurface {
  _PersistedOpacity(Object paintedBy, this.alpha, this.offset)
      : super(paintedBy);

  final int alpha;
  final Offset offset;

  @override
  html.Element createElement() {
    return defaultCreateElement('flt-opacity')..style.transformOrigin = '0 0 0';
  }

  @override
  void apply() {
    rootElement.style.opacity = '${alpha / 255}';
    rootElement.style.transform = 'translate(${offset.dx}px, ${offset.dy}px)';
  }

  @override
  void update(_PersistedOpacity oldSurface) {
    super.update(oldSurface);
    if (alpha != oldSurface.alpha || offset != oldSurface.offset) {
      apply();
    }
  }
}

// TODO(yjbanov): this is currently very naive. We probably want to cache
//                fewer large canvases than small canvases. We could also
//                improve cache hit count if we did not require exact canvas
//                size match, but instead could choose a canvas that's big
//                enough. The optimal heuristic will need to be figured out.
//                For example, we probably don't want to pick a full-screen
//                canvas to draw a 10x10 picture. Let's revisit this after
//                Harry's layer merging refactor.
/// The maximum number canvases cached.
const _kCanvasCacheSize = 30;

/// Canvases available for reuse, capped at [_kCanvasCacheSize].
final List<BitmapCanvas> _recycledCanvases = <BitmapCanvas>[];

/// Callbacks produced by [_PersistedPicture]s that actually paint on the
/// canvas. Painting is delayed until the layer tree is updated to maximize
/// the number of reusable canvases.
List<VoidCallback> _paintQueue = <VoidCallback>[];

void _recycleCanvas(EngineCanvas canvas) {
  if (canvas is BitmapCanvas) {
    _recycledCanvases.add(canvas);
    if (_recycledCanvases.length > _kCanvasCacheSize) {
      _recycledCanvases.removeAt(0);
    }
  }
}

/// Signature of a function that instantiates a [_PersistedPicture].
typedef PersistedPictureFactory = _PersistedPicture Function(
    Object webOnlyPaintedBy, double dx, double dy, Picture picture, int hints);

/// Function used by the [SceneBuilder] to instantiate a picture layer.
PersistedPictureFactory persistedPictureFactory = standardPictureFactory;

/// Instantiates an implementation of a picture layer that uses DOM, CSS, and
/// 2D canvas for painting.
_PersistedStandardPicture standardPictureFactory(
    Object webOnlyPaintedBy, double dx, double dy, Picture picture, int hints) {
  return _PersistedStandardPicture(webOnlyPaintedBy, dx, dy, picture, hints);
}

/// Instantiates an implementation of a picture layer that uses CSS Paint API
/// (part of Houdini) for painting.
_PersistedHoudiniPicture houdiniPictureFactory(
    Object webOnlyPaintedBy, double dx, double dy, Picture picture, int hints) {
  return _PersistedHoudiniPicture(webOnlyPaintedBy, dx, dy, picture, hints);
}

class _PersistedHoudiniPicture extends _PersistedPicture {
  _PersistedHoudiniPicture(
      Object paintedBy, double dx, double dy, Picture picture, int hints)
      : super(paintedBy, dx, dy, picture, hints) {
    if (!_cssPainterRegistered) {
      _registerCssPainter();
    }
  }

  static bool _cssPainterRegistered = false;

  static void _registerCssPainter() {
    _cssPainterRegistered = true;
    final dynamic css = js_util.getProperty(html.window, 'CSS');
    final dynamic paintWorklet = js_util.getProperty(css, 'paintWorklet');
    if (paintWorklet == null) {
      html.window.console.warn(
          'WARNING: CSS.paintWorklet not available. Paint worklets are only '
          'supported on sites served from https:// or http://localhost.');
      return;
    }
    js_util.callMethod(
      paintWorklet,
      'addModule',
      [
        '/packages/flutter_web/assets/houdini_painter.js',
      ],
    );
  }

  @override
  void applyPaint(EngineCanvas oldCanvas) {
    _recycleCanvas(oldCanvas);
    final HoudiniCanvas canvas = HoudiniCanvas(_computeCanvasBounds());
    _canvas = canvas;
    domRenderer.clearDom(rootElement);
    rootElement.append(_canvas.rootElement);
    picture.recordingCanvas.apply(_canvas);
    canvas.commit();
  }
}

class _PersistedStandardPicture extends _PersistedPicture {
  _PersistedStandardPicture(
      Object paintedBy, double dx, double dy, Picture picture, int hints)
      : super(paintedBy, dx, dy, picture, hints);

  bool _debugDidReuseCanvas = false;
  bool _debugDidAllocateNewCanvas = false;

  @override
  void applyPaint(EngineCanvas oldCanvas) {
    if (picture.recordingCanvas.hasArbitraryPaint) {
      _applyBitmapPaint(oldCanvas);
    } else {
      _applyDomPaint(oldCanvas);
    }
  }

  void _applyDomPaint(EngineCanvas oldCanvas) {
    _recycleCanvas(oldCanvas);
    _canvas = DomCanvas();
    domRenderer.clearDom(rootElement);
    rootElement.append(_canvas.rootElement);
    picture.recordingCanvas.apply(_canvas);
  }

  void _applyBitmapPaint(EngineCanvas oldCanvas) {
    final Rect bounds = _computeCanvasBounds();
    if (oldCanvas == null ||
        oldCanvas is DomCanvas ||
        oldCanvas is BitmapCanvas && bounds != oldCanvas.bounds) {
      // We can't use the old canvas because the size has changed, so we put
      // it in a cache for later reuse.
      _recycleCanvas(oldCanvas);
      // We cannot paint immediately because not all canvases that we may be
      // able to reuse have been released yet. So instead we enqueue this
      // picture to be painted after the update cycle is done syncing the layer
      // tree then reuse canvases that were freed up.
      _paintQueue.add(() {
        _canvas = _findOrCreateCanvas(bounds);
        domRenderer.clearDom(rootElement);
        rootElement.append(_canvas.rootElement);
        picture.recordingCanvas.apply(_canvas);
      });
    } else {
      _canvas = oldCanvas;
      picture.recordingCanvas.apply(_canvas);
    }
  }

  /// Attempts to reuse a canvas from the [_recycledCanvases]. Allocates a new
  /// one if unable to reuse.
  ///
  /// The best recycled canvas is one that:
  ///
  /// - Fits the requested [canvasSize]. This is a hard requirement. Otherwise
  ///   we risk clipping the picture.
  /// - Is the smallest among all possible reusable canvases. This makes canvas
  ///   reuse more efficient.
  /// - Contains no more than twice the number of requested pixels. This makes
  ///   sure we do not use too much memory for small canvases.
  BitmapCanvas _findOrCreateCanvas(Rect bounds) {
    Size canvasSize = bounds.size;
    BitmapCanvas bestRecycledCanvas;
    double lastPixelCount = double.infinity;
    for (int i = 0; i < _recycledCanvases.length; i++) {
      BitmapCanvas candidate = _recycledCanvases[i];
      Size candidateSize = candidate.size;
      double pixelCount = canvasSize.width * canvasSize.height;
      double candidatePixelCount = candidateSize.width * candidateSize.height;

      bool fits = candidateSize.width >= canvasSize.width &&
          candidateSize.height >= canvasSize.height;
      bool tooBig = candidatePixelCount > lastPixelCount ||
          (candidatePixelCount / pixelCount) > 2.0;
      if (fits && !tooBig) {
        bestRecycledCanvas = candidate;
        lastPixelCount = candidatePixelCount;
      }
    }

    if (bestRecycledCanvas != null) {
      _debugDidReuseCanvas = true;
      _recycledCanvases.remove(bestRecycledCanvas);
      bestRecycledCanvas.bounds = bounds;
      return bestRecycledCanvas;
    }

    _debugDidAllocateNewCanvas = true;
    return BitmapCanvas(bounds);
  }
}

/// A surface that uses a combination of `<canvas>`, `<div>` and `<p>` elements
/// to draw shapes and text.
abstract class _PersistedPicture extends _PersistedLeafSurface {
  _PersistedPicture(
      Object paintedBy, this.dx, this.dy, this.picture, this.hints)
      : super(paintedBy);

  EngineCanvas _canvas;

  final double dx;
  final double dy;
  final Picture picture;
  final int hints;

  bool _debugDidNotPaint = false;

  @override
  html.Element createElement() {
    return defaultCreateElement('flt-picture');
  }

  /// Computes the canvas paint bounds based on the estimated paint bounds and
  /// the scaling produced by transformations.
  Rect _computeCanvasBounds() {
    final Matrix4 effectiveTransform = Matrix4.identity();
    _PersistedContainerSurface parent = this.parent;
    while (parent != null) {
      if (parent is _PersistedTransform) {
        effectiveTransform.multiply(Matrix4.fromFloat64List(parent.matrix4));
      }
      parent = parent.parent;
    }

    final shift = effectiveTransform.transform(Vector4(0.0, 0.0, 0.0, 1.0));
    final scaleX =
        (effectiveTransform.transform(Vector4(1.0, 0.0, 0.0, 1.0)) - shift)
            .x
            .abs();
    final scaleY =
        (effectiveTransform.transform(Vector4(0.0, 1.0, 0.0, 1.0)) - shift)
            .y
            .abs();

    final Rect bounds = picture.recordingCanvas.computePaintBounds();
    Size canvasSize = bounds.size;
    final double screenWidth =
        window.physicalSize.width / window.devicePixelRatio;
    final double screenHeight =
        window.physicalSize.height / window.devicePixelRatio;
    canvasSize = Size(
      math.min(canvasSize.width * math.max(scaleX, 1.0), screenWidth),
      math.min(canvasSize.height * math.max(scaleY, 1.0), screenHeight),
    );
    // TODO(yjbanov): should we inflate the bounds instead?
    return bounds.topLeft & canvasSize;
  }

  void _applyPaint(EngineCanvas oldCanvas) {
    if (!picture.recordingCanvas.didDraw) {
      _recycleCanvas(oldCanvas);
      domRenderer.clearDom(rootElement);
      return;
    }

    applyPaint(oldCanvas);
  }

  /// Concrete implementations implement this method to do actual painting.
  void applyPaint(EngineCanvas oldCanvas);

  void _applyTranslate() {
    rootElement.style.transform = 'translate(${dx}px, ${dy}px)';
  }

  @override
  void apply() {
    _applyTranslate();
    _applyPaint(null);
  }

  @override
  void update(_PersistedPicture oldSurface) {
    super.update(oldSurface);

    if (dx != oldSurface.dx || dy != oldSurface.dy) {
      _applyTranslate();
    }

    if (!identical(picture, oldSurface.picture)) {
      // The picture was repainted. Attempt to repaint into the existing canvas.
      _applyPaint(oldSurface._canvas);
    } else {
      // The picture was not repainted, just adopt its canvas and do nothing.
      _debugDidNotPaint = true;
      _canvas = oldSurface._canvas;
    }
  }

  @override
  void recycle() {
    _recycleCanvas(_canvas);
    super.recycle();
  }

  @override
  void debugPrintChildren(StringBuffer buffer, int indent) {
    super.debugPrintChildren(buffer, indent);
    if (rootElement != null) {
      final canvasTag =
          (rootElement.firstChild as html.Element).tagName.toLowerCase();
      final canvasHash = rootElement.firstChild.hashCode;
      buffer.writeln('${'  ' * (indent + 1)}<$canvasTag @$canvasHash />');
    } else {
      buffer.writeln('${'  ' * (indent + 1)}<canvas recycled />');
    }
  }
}

class _PersistedPhysicalShape extends _PersistedContainerSurface with _DomClip {
  _PersistedPhysicalShape(Object paintedBy, this.path, this.elevation,
      int color, int shadowColor, this.clipBehavior)
      : this.color = Color(color),
        this.shadowColor = Color(shadowColor),
        super(paintedBy);

  final Path path;
  final double elevation;
  final Color color;
  final Color shadowColor;
  final Clip clipBehavior;

  void _applyColor() {
    rootElement.style.backgroundColor = color.toCssString();
  }

  void _applyShadow() {
    ElevationShadow.applyShadow(rootElement.style, elevation, shadowColor);
  }

  @override
  html.Element createElement() {
    return super.createElement()..setAttribute('clip-type', 'physical-shape');
  }

  @override
  void apply() {
    _applyColor();
    _applyShadow();
    _applyShape();
  }

  void _applyShape() {
    if (path == null) return;
    // Handle special case of round rect physical shape mapping to
    // rounded div.
    final RRect roundRect = path.webOnlyPathAsRoundedRect;
    if (roundRect != null) {
      final borderRadius = '${roundRect.tlRadiusX}px ${roundRect.trRadiusX}px '
          '${roundRect.blRadiusX}px ${roundRect.brRadiusX}px';
      var style = rootElement.style;
      style
        ..transform = 'translate(${roundRect.left}px, ${roundRect.top}px)'
        ..width = '${roundRect.width}px'
        ..height = '${roundRect.height}px'
        ..borderRadius = borderRadius;
      childContainer.style.transform =
          'translate(${-roundRect.left}px, ${-roundRect.top}px)';
      if (clipBehavior != Clip.none) {
        style.overflow = 'hidden';
      }
      return;
    } else {
      Rect rect = path.webOnlyPathAsRect;
      if (rect != null) {
        final style = rootElement.style;
        style
          ..transform = 'translate(${rect.left}px, ${rect.top}px)'
          ..width = '${rect.width}px'
          ..height = '${rect.height}px';
        childContainer.style.transform =
            'translate(${-rect.left}px, ${-rect.top}px)';
        if (clipBehavior != Clip.none) {
          style.overflow = 'hidden';
        }
        return;
      }
    }
    // TODO: apply path via clip-path CSS property.
    throw new UnimplementedError(
        'Arbitrary path physical shape not supported yet');
  }

  @override
  void update(_PersistedPhysicalShape oldSurface) {
    super.update(oldSurface);
    if (oldSurface.color != color) {
      _applyColor();
    }
    if (oldSurface.elevation != elevation ||
        oldSurface.shadowColor != shadowColor) {
      _applyShadow();
    }
    if (oldSurface.path != path) {
      _applyShape();
    }
  }
}
