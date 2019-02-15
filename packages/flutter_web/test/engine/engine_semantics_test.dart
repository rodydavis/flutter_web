// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:quiver/testing/async.dart';

import 'package:flutter_web/widgets.dart';
import 'package:flutter_web_test/flutter_web_test.dart';
import 'package:flutter_web_ui/src/engine/semantics.dart';
import 'package:flutter_web_ui/ui.dart' as ui;

import '../widgets/semantics_tester.dart';

DateTime _testTime = DateTime(2018, 12, 17);

EngineSemanticsOwner semantics() => EngineSemanticsOwner.instance;

void main() {
  setUp(() {
    EngineSemanticsOwner.debugResetSemantics();
  });

  group(EngineSemanticsOwner, () {
    _testEngineSemanticsOwner();
  });
  group('longestIncreasingSubsequence', () {
    _testLongestIncreasingSubsequence();
  });
  group('container', () {
    _testContainer();
  });
  group('vertical scrolling', () {
    _testVerticalScrolling();
  });
  group('horizontal scrolling', () {
    _testHorizontalScrolling();
  });
  group('incrementable', () {
    _testIncrementables();
  });
}

void _testEngineSemanticsOwner() {
  testWidgets('instantiates a singleton', (_) async {
    expect(semantics(), same(semantics()));
  });

  testWidgets('semantics is off by default', (_) async {
    expect(semantics().semanticsEnabled, false);
  });

  testWidgets('default mode is "unknown"', (_) async {
    expect(semantics().mode, AccessibilityMode.unknown);
  });

  testWidgets('produces an aria-label', (WidgetTester tester) async {
    semantics().semanticsEnabled = true;
    final SemanticsTester semanticsTester = SemanticsTester(tester);

    // Create
    await tester.pumpWidget(
      Text('Hello', textDirection: TextDirection.ltr),
    );

    final tree = semantics().debugSemanticsTree;
    expect(tree.length, 2);
    expect(tree[0].id, 0);
    expect(tree[0].element.tagName.toLowerCase(), 'flt-semantics');

    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <sem-c>
    <sem aria-label="Hello">
      <sem-v>Hello</sem-v>
    </sem>
  </sem-c>
</sem>''');

    // Update
    await tester.pumpWidget(
      Text('World', textDirection: TextDirection.ltr),
    );

    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <sem-c>
    <sem aria-label="World">
      <sem-v>World</sem-v>
    </sem>
  </sem-c>
</sem>''');

    // Remove
    await tester.pumpWidget(
      Text('', textDirection: TextDirection.ltr),
    );

    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    semanticsTester.dispose();
    semantics().semanticsEnabled = false;
  });

  testWidgets('clears semantics tree when disabled',
      (WidgetTester tester) async {
    expect(semantics().debugSemanticsTree, isEmpty);
    semantics().semanticsEnabled = true;
    final SemanticsTester semanticsTester = SemanticsTester(tester);
    await tester.pumpWidget(Text('Hello', textDirection: TextDirection.ltr));
    expect(semantics().debugSemanticsTree, isNotEmpty);
    semantics().semanticsEnabled = false;
    expect(semantics().debugSemanticsTree, isEmpty);
    semanticsTester.dispose();
  });

  testWidgets('accepts standalone browser gestures',
      (WidgetTester tester) async {
    semantics().semanticsEnabled = true;
    expect(semantics().shouldAcceptBrowserGesture('click'), true);
    semantics().semanticsEnabled = false;
  });

  test('rejects browser gestures accompanied by pointer click', () {
    FakeAsync().run((fakeAsync) {
      semantics()
        ..debugOverrideTimestampFunction(fakeAsync.getClock(_testTime).now)
        ..semanticsEnabled = true;
      expect(semantics().shouldAcceptBrowserGesture('click'), true);
      semantics().receiveGlobalEvent(html.Event('pointermove'));
      expect(semantics().shouldAcceptBrowserGesture('click'), false);

      // After 1 second of inactivity a browser gestures counts as standalone.
      fakeAsync.elapse(Duration(seconds: 1));
      expect(semantics().shouldAcceptBrowserGesture('click'), true);
      semantics().semanticsEnabled = false;
    });
  });
}

void _testLongestIncreasingSubsequence() {
  expectLis(List<int> list, List<int> seq) {
    expect(longestIncreasingSubsequence(list), seq);
  }

  test('trivial case', () {
    expectLis(<int>[], <int>[]);
  });

  test('longest in the middle', () {
    expectLis([10, 1, 2, 3, 0], [1, 2, 3]);
  });

  test('longest at head', () {
    expectLis([1, 2, 3, 0], [0, 1, 2]);
  });

  test('longest at tail', () {
    expectLis([10, 1, 2, 3], [1, 2, 3]);
  });

  test('longest in a jagged pattern', () {
    expectLis([0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5], [0, 1, 3, 5, 7, 9]);
  });

  test('fully sorted up', () {
    for (int count = 0; count < 100; count += 1) {
      expectLis(
        List<int>.generate(count, (i) => 10 * i),
        List<int>.generate(count, (i) => i),
      );
    }
  });

  test('fully sorted down', () {
    for (int count = 1; count < 100; count += 1) {
      expectLis(
        List<int>.generate(count, (i) => 10 * (count - i)),
        <int>[count - 1],
      );
    }
  });
}

void _testContainer() {
  testWidgets('container node has no transform when there is no rect offset',
      (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    final ui.Rect zeroOffsetRect = ui.Rect.fromLTRB(0, 0, 20, 20);
    builder.updateNode(
      id: 0,
      actions: 0,
      transform: Matrix4.identity().storage,
      rect: zeroOffsetRect,
      childrenInHitTestOrder: Int32List.fromList([1]),
      childrenInTraversalOrder: Int32List.fromList([1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    html.Element parentElement = html.document.querySelector('flt-semantics');
    html.Element container =
        html.document.querySelector('flt-semantics-container');

    expect(parentElement.style.transform, '');
    expect(parentElement.style.transformOrigin, '');
    expect(container.style.transform, '');
    expect(container.style.transformOrigin, '');

    semantics().semanticsEnabled = false;
  });

  testWidgets('container node compensates for rect offset',
      (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0,
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(10, 10, 20, 20),
      childrenInHitTestOrder: Int32List.fromList([1]),
      childrenInTraversalOrder: Int32List.fromList([1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    html.Element parentElement = html.document.querySelector('flt-semantics');
    html.Element container =
        html.document.querySelector('flt-semantics-container');

    expect(parentElement.style.transform,
        'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 10, 10, 0, 1)');
    expect(parentElement.style.transformOrigin, '0px 0px 0px');
    expect(container.style.transform, 'translate(-10px, -10px)');
    expect(container.style.transformOrigin, '0px 0px 0px');

    semantics().semanticsEnabled = false;
  });
}

void _testVerticalScrolling() {
  testWidgets('renders an empty scrollable node', (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 | SemanticsAction.scrollUp.index,
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 50, 100),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0); touch-action: none; overflow-y: scroll">
</sem>''');

    semantics().semanticsEnabled = false;
  });

  testWidgets('scrollable node with children has a container node',
      (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 | SemanticsAction.scrollUp.index,
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 50, 100),
      childrenInHitTestOrder: Int32List.fromList([1]),
      childrenInTraversalOrder: Int32List.fromList([1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0); touch-action: none; overflow-y: scroll">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    html.Element scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's less content than the available size the neutral scrollTop
    // is 0.
    expect(scrollable.scrollTop, 0);

    semantics().semanticsEnabled = false;
  });

  test('scrollable node dispatches scroll events', () async {
    final StreamController<int> idLogController = StreamController<int>();
    final StreamController<SemanticsAction> actionLogController =
        StreamController<SemanticsAction>();
    final Stream<int> idLog = idLogController.stream.asBroadcastStream();
    final Stream<SemanticsAction> actionLog =
        actionLogController.stream.asBroadcastStream();

    // The browser kicks us out of the test zone when the scroll event happens.
    // We memorize the test zone so we can call expect when the callback is
    // fired.
    var testZone = Zone.current;

    ui.window.onSemanticsAction =
        (int id, SemanticsAction action, ByteData args) {
      idLogController.add(id);
      actionLogController.add(action);
      testZone.run(() {
        expect(args, null);
      });
    };
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions:
          0 | SemanticsAction.scrollUp.index | SemanticsAction.scrollDown.index,
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 50, 100),
      childrenInHitTestOrder: Int32List.fromList([1, 2, 3]),
      childrenInTraversalOrder: Int32List.fromList([1, 2, 3]),
    );

    for (int id = 1; id <= 3; id++) {
      builder.updateNode(
        id: id,
        actions: 0,
        transform: Matrix4.translationValues(0, 50.0 * id, 0).storage,
        rect: ui.Rect.fromLTRB(0, 0, 50, 50),
      );
    }

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0); touch-action: none; overflow-y: scroll">
  <sem-c>
    <sem></sem>
    <sem></sem>
    <sem></sem>
  </sem-c>
</sem>''');

    html.Element scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's more content than the available size the neutral scrollTop
    // is greater than 0 with a maximum of 10.
    expect(scrollable.scrollTop, 10);

    scrollable.scrollTop = 20;
    expect(scrollable.scrollTop, 20);
    expect(await idLog.first, 0);
    expect(await actionLog.first, SemanticsAction.scrollUp);
    // Engine semantics returns scroll top back to neutral.
    expect(scrollable.scrollTop, 10);

    scrollable.scrollTop = 5;
    expect(scrollable.scrollTop, 5);
    expect(await idLog.first, 0);
    expect(await actionLog.first, SemanticsAction.scrollDown);
    // Engine semantics returns scroll top back to neutral.
    expect(scrollable.scrollTop, 10);

    semantics().semanticsEnabled = false;
  });
}

void _testHorizontalScrolling() {
  testWidgets('renders an empty scrollable node', (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 | SemanticsAction.scrollLeft.index,
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0); touch-action: none; overflow-x: scroll">
</sem>''');

    semantics().semanticsEnabled = false;
  });

  testWidgets('scrollable node with children has a container node',
      (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 | SemanticsAction.scrollLeft.index,
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 100, 50),
      childrenInHitTestOrder: Int32List.fromList([1]),
      childrenInTraversalOrder: Int32List.fromList([1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0); touch-action: none; overflow-x: scroll">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    html.Element scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's less content than the available size the neutral
    // scrollLeft is 0.
    expect(scrollable.scrollLeft, 0);

    semantics().semanticsEnabled = false;
  });

  test('scrollable node dispatches scroll events', () async {
    final SemanticsActionLogger logger = SemanticsActionLogger();
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 |
          SemanticsAction.scrollLeft.index |
          SemanticsAction.scrollRight.index,
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 100, 50),
      childrenInHitTestOrder: Int32List.fromList([1, 2, 3]),
      childrenInTraversalOrder: Int32List.fromList([1, 2, 3]),
    );

    for (int id = 1; id <= 3; id++) {
      builder.updateNode(
        id: id,
        actions: 0,
        transform: Matrix4.translationValues(50.0 * id, 0, 0).storage,
        rect: ui.Rect.fromLTRB(0, 0, 50, 50),
      );
    }

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0); touch-action: none; overflow-x: scroll">
  <sem-c>
    <sem></sem>
    <sem></sem>
    <sem></sem>
  </sem-c>
</sem>''');

    html.Element scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's more content than the available size the neutral scrollTop
    // is greater than 0 with a maximum of 10.
    expect(scrollable.scrollLeft, 10);

    scrollable.scrollLeft = 20;
    expect(scrollable.scrollLeft, 20);
    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, SemanticsAction.scrollLeft);
    // Engine semantics returns scroll position back to neutral.
    expect(scrollable.scrollLeft, 10);

    scrollable.scrollLeft = 5;
    expect(scrollable.scrollLeft, 5);
    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, SemanticsAction.scrollRight);
    // Engine semantics returns scroll top back to neutral.
    expect(scrollable.scrollLeft, 10);

    semantics().semanticsEnabled = false;
  });
}

void _testIncrementables() {
  testWidgets('renders a trivial incrementable node',
      (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 | SemanticsAction.increase.index,
      value: 'd',
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="1" aria-valuemin="1">
</sem>''');

    semantics().semanticsEnabled = false;
  });

  testWidgets('increments', (WidgetTester tester) async {
    final SemanticsActionLogger logger = SemanticsActionLogger();
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 | SemanticsAction.increase.index,
      value: 'd',
      increasedValue: 'e',
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="2" aria-valuemin="1">
</sem>''');

    html.InputElement input = html.document.querySelectorAll('input').single;
    input.value = '2';
    input.dispatchEvent(html.Event('change'));

    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, SemanticsAction.increase);

    semantics().semanticsEnabled = false;
  });

  testWidgets('decrements', (WidgetTester tester) async {
    final SemanticsActionLogger logger = SemanticsActionLogger();
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions: 0 | SemanticsAction.decrease.index,
      value: 'd',
      decreasedValue: 'c',
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="1" aria-valuemin="0">
</sem>''');

    html.InputElement input = html.document.querySelectorAll('input').single;
    input.value = '0';
    input.dispatchEvent(html.Event('change'));

    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, SemanticsAction.decrease);

    semantics().semanticsEnabled = false;
  });

  testWidgets('renders a node that can both increment and decrement',
      (WidgetTester tester) async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    builder.updateNode(
      id: 0,
      actions:
          0 | SemanticsAction.decrease.index | SemanticsAction.increase.index,
      value: 'd',
      increasedValue: 'e',
      decreasedValue: 'c',
      transform: Matrix4.identity().storage,
      rect: ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="opacity: 0; color: rgba(0, 0, 0, 0)">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="2" aria-valuemin="0">
</sem>''');

    semantics().semanticsEnabled = false;
  });
}

void expectSemanticsTree(String semanticsHtml) {
  expect(
    canonicalizeHtml(html.document.querySelector('flt-semantics').outerHtml),
    canonicalizeHtml(semanticsHtml),
  );
}

html.Element findScrollable() {
  return html.document.querySelectorAll('flt-semantics').firstWhere(
        (html.Element element) =>
            element.style.overflow == 'hidden' ||
            element.style.overflowY == 'scroll' ||
            element.style.overflowX == 'scroll',
        orElse: () => null,
      );
}

class SemanticsActionLogger {
  StreamController<int> idLogController;
  StreamController<SemanticsAction> actionLogController;
  Stream<int> idLog;
  Stream<SemanticsAction> actionLog;

  SemanticsActionLogger() {
    idLogController = StreamController<int>();
    actionLogController = StreamController<SemanticsAction>();
    idLog = idLogController.stream.asBroadcastStream();
    actionLog = actionLogController.stream.asBroadcastStream();

    // The browser kicks us out of the test zone when the browser event happens.
    // We memorize the test zone so we can call expect when the callback is
    // fired.
    var testZone = Zone.current;

    ui.window.onSemanticsAction =
        (int id, SemanticsAction action, ByteData args) {
      idLogController.add(id);
      actionLogController.add(action);
      testZone.run(() {
        expect(args, null);
      });
    };
  }
}
