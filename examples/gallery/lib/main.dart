// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web/material.dart';
import 'package:flutter_web_ui/src/engine.dart' as engine;

import 'gallery/app.dart';

void main() {
  // TODO(yjbanov): figure out what API to provide for controlling semantics. We
  //                are in a similar situation as the location strategy in that
  //                we have to bootstrap things differently on the Web compared
  //                to Flutter native.
  engine.EngineSemanticsOwner.instance.semanticsEnabled = true;

  runApp(GalleryApp());
}
