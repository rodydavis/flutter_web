// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../canvas.dart';
import '../compositing.dart';
import '../geometry.dart';
import '../painting.dart';
import 'layer.dart';
import 'layer_tree.dart';

class EngineLayerImpl extends EngineLayer {
  final ContainerLayer _layer;

  EngineLayerImpl(this._layer);
}

class LayerScene implements Scene {
  final LayerTree layerTree;

  LayerScene(Layer rootLayer) : layerTree = LayerTree() {
    layerTree.rootLayer = rootLayer;
  }

  @override
  void dispose() {}

  @override
  Future<Image> toImage(int width, int height) => null;

  @override
  Element get webOnlyRootElement => null;
}

class LayerSceneBuilder implements SceneBuilder {
  Layer rootLayer;
  ContainerLayer currentLayer;

  @override
  void addChildScene(
      {Offset offset = Offset.zero,
      double width = 0.0,
      double height = 0.0,
      SceneHost sceneHost,
      bool hitTestable = true}) {
    throw new UnimplementedError();
  }

  @override
  void addPerformanceOverlay(int enabledOptions, Rect bounds,
      {Object webOnlyPaintedBy}) {
    // TODO: implement addPerformanceOverlay
  }

  @override
  void addPicture(Offset offset, Picture picture,
      {bool isComplexHint = false,
      bool willChangeHint = false,
      Object webOnlyPaintedBy}) {
    currentLayer
        .add(PictureLayer(picture, offset, isComplexHint, willChangeHint));
  }

  @override
  void addRetained(EngineLayer retainedLayer) {
    if (currentLayer == null) return;
    currentLayer.add((retainedLayer as EngineLayerImpl)._layer);
  }

  @override
  void addTexture(int textureId,
      {Offset offset = Offset.zero,
      double width = 0.0,
      double height = 0.0,
      bool freeze = false,
      Object webOnlyPaintedBy}) {
    // TODO: implement addTexture
  }

  @override
  Scene build() {
    return LayerScene(rootLayer);
  }

  @override
  void pop() {
    if (currentLayer == null) return;
    currentLayer = currentLayer.parent;
  }

  @override
  void pushBackdropFilter(ImageFilter filter, {Object webOnlyPaintedBy}) {
    throw new UnimplementedError();
  }

  @override
  void pushClipPath(Path path,
      {Clip clipBehavior = Clip.antiAlias, Object webOnlyPaintedBy}) {
    pushLayer(ClipPathLayer(path));
  }

  @override
  void pushClipRRect(RRect rrect,
      {Clip clipBehavior, Object webOnlyPaintedBy}) {
    pushLayer(ClipRRectLayer(rrect));
  }

  @override
  void pushClipRect(Rect rect,
      {Clip clipBehavior = Clip.antiAlias, Object webOnlyPaintedBy}) {
    pushLayer(ClipRectLayer(rect));
  }

  @override
  void pushColorFilter(Color color, BlendMode blendMode,
      {Object webOnlyPaintedBy}) {
    throw new UnimplementedError();
  }

  @override
  EngineLayer pushOffset(double dx, double dy, {Object webOnlyPaintedBy}) {
    final matrix = Matrix4.translationValues(dx, dy, 0.0);
    final layer = TransformLayer(matrix);
    pushLayer(layer);
    return EngineLayerImpl(layer);
  }

  @override
  void pushOpacity(int alpha,
      {Object webOnlyPaintedBy, Offset offset = Offset.zero}) {
    // TODO(het): Implement opacity
    pushOffset(0.0, 0.0);
  }

  @override
  EngineLayer pushPhysicalShape(
      {Path path,
      double elevation,
      Color color,
      Color shadowColor,
      Clip clipBehavior = Clip.none,
      Object webOnlyPaintedBy}) {
    final layer =
        PhysicalShapeLayer(elevation, color, shadowColor, path, clipBehavior);
    pushLayer(layer);
    return EngineLayerImpl(layer);
  }

  @override
  void pushShaderMask(Shader shader, Rect maskRect, BlendMode blendMode,
      {Object webOnlyPaintedBy}) {
    throw new UnimplementedError();
  }

  @override
  void pushTransform(Float64List matrix4, {Object webOnlyPaintedBy}) {
    final matrix = Matrix4.fromList(matrix4);
    pushLayer(TransformLayer(matrix));
  }

  @override
  void setCheckerboardOffscreenLayers(bool checkerboard) {
    // TODO: implement setCheckerboardOffscreenLayers
  }

  @override
  void setCheckerboardRasterCacheImages(bool checkerboard) {
    // TODO: implement setCheckerboardRasterCacheImages
  }

  @override
  void setRasterizerTracingThreshold(int frameInterval) {
    // TODO: implement setRasterizerTracingThreshold
  }

  void pushLayer(ContainerLayer layer) {
    if (rootLayer == null) {
      rootLayer = currentLayer = layer;
      return;
    }

    if (currentLayer == null) return;

    currentLayer.add(layer);
    currentLayer = layer;
  }
}
