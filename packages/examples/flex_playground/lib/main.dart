// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web/material.dart';

void main() {
  runApp(new Directionality(
    textDirection: TextDirection.ltr,
    child: new Row(
      children: <Widget>[
        new Flexible(child: Text('Hello')),
        new Flexible(child: new Text('World')),
        new Image.asset('images/barchart.jpg'),
        new Image.asset('images/linechart.jpg'),
      ],
    ),
  ));
}
