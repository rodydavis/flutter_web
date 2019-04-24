// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Called by https://pub.dartlang.org/packages/peanut to generate example pages
// for hosting.

import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) {
  final sourcePath = args.single;

  for (var htmlFile in Directory(sourcePath)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => p.basename(f.path) == 'index.html')) {
    final content = htmlFile.readAsStringSync();
    final newContent = content.replaceFirst('<head>', '<head>\n$_analytics');

    final filePath = p.relative(htmlFile.path, from: sourcePath);

    if (newContent == content) {
      print('!!! Did not replace contents in $filePath');
    } else {
      print('Replaced contents in $filePath');
      htmlFile.writeAsStringSync(newContent);
    }
  }
}

const _analytics = r'''
<script async src="https://www.googletagmanager.com/gtag/js?id=UA-26406144-35"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'UA-26406144-35');
</script>''';
