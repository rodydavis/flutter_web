// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

const _dirs = ['packages', 'examples'];

const _ansiGreen = 32;
const _ansiRed = 31;
const _ansiMagenta = 35;

void main() async {
  var packageDirs = _listPackageDirs().toList()..sort();
  print('Package dir count: ${packageDirs.length}');
  var results = <bool>[];
  for (var dir in packageDirs) {
    _logWrapped(_ansiMagenta, dir);
    results.add(await _run(dir, 'pub', ['upgrade', '--no-precompile']));
    results.add(await _run(
      dir,
      'dartanalyzer',
      ['--fatal-infos', '--fatal-warnings', '.'],
    ));
    _printStatus(results);
  }

  if (results.any((v) => !v)) {
    exitCode = 1;
  }
}

void _printStatus(List<bool> results) {
  var successCount = results.where((t) => t).length;
  var success = (successCount == results.length);
  var pct = 100 * successCount / results.length;

  _logWrapped(success ? _ansiGreen : _ansiRed,
      '$successCount of ${results.length} (${pct.toStringAsFixed(2)}%)');
}

void _logWrapped(int code, String message) {
  print('\x1B[${code}m$message\x1B[0m');
}

Future<bool> _run(
    String workingDir, String commandName, List<String> args) async {
  var commandDescription = '`${([commandName]..addAll(args)).join(' ')}`';

  _logWrapped(_ansiMagenta, '  Running $commandDescription');

  var proc = await Process.start(
    commandName,
    args,
    workingDirectory: workingDir,
    mode: ProcessStartMode.inheritStdio,
  );

  var exitCode = await proc.exitCode;

  if (exitCode != 0) {
    _logWrapped(
        _ansiRed, '  Failed! ($exitCode) – $workingDir – $commandDescription');
    return false;
  } else {
    _logWrapped(_ansiGreen, '  Success! – $workingDir – $commandDescription');
    return true;
  }
}

Iterable<String> _listPackageDirs() sync* {
  for (var dir in _dirs) {
    for (var subDir in Directory(dir)
        .listSync(recursive: false, followLinks: false)
        .whereType<Directory>()) {
      if (File('${subDir.path}/pubspec.yaml').existsSync()) {
        yield subDir.path;
      }
    }
  }
}
