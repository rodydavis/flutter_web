// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:flutter_web_ui/ui.dart' as ui;
import 'package:flutter_web_ui/ui.dart';
import 'package:flutter_web_ui/src/dom_renderer.dart';

import 'src/widgets/binding.dart' as binding;
import 'src/widgets/framework.dart';

export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'package:flutter_web/foundation.dart';
export 'package:flutter_web/physics.dart';
export 'package:flutter_web/scheduler.dart';
export 'package:flutter_web/services.dart';

export 'src/widgets/animated_cross_fade.dart';
export 'src/widgets/animated_list.dart';
export 'src/widgets/animated_size.dart';
export 'src/widgets/annotated_region.dart';
export 'src/widgets/animated_switcher.dart';
export 'src/widgets/async.dart';
export 'src/widgets/automatic_keep_alive.dart';
export 'src/widgets/app.dart';
export 'src/widgets/automatic_keep_alive.dart';
export 'src/widgets/banner.dart';
export 'src/widgets/basic.dart';
export 'src/widgets/binding.dart';
export 'src/widgets/bottom_navigation_bar_item.dart';
export 'src/widgets/container.dart';
export 'src/widgets/debug.dart';
export 'src/widgets/dismissable.dart';
export 'src/widgets/drag_target.dart';
export 'src/widgets/editable_text.dart';
export 'src/widgets/fade_in_image.dart';
export 'src/widgets/focus_scope.dart';
export 'src/widgets/focus_manager.dart';
export 'src/widgets/form.dart';
export 'src/widgets/framework.dart';
export 'src/widgets/gesture_detector.dart';
export 'src/widgets/grid_paper.dart';
export 'src/widgets/heroes.dart';
export 'src/widgets/icon.dart';
export 'src/widgets/icon_data.dart';
export 'src/widgets/icon_theme.dart';
export 'src/widgets/icon_theme_data.dart';
export 'src/widgets/image_icon.dart';
export 'src/widgets/image.dart';
export 'src/widgets/inherited_model.dart';
export 'src/widgets/inherited_notifier.dart';
export 'src/widgets/implicit_animations.dart';
export 'src/widgets/layout_builder.dart';
export 'src/widgets/list_wheel_scroll_view.dart';
export 'src/widgets/localizations.dart';
export 'src/widgets/media_query.dart';
export 'src/widgets/modal_barrier.dart';
export 'src/widgets/navigation_toolbar.dart';
export 'src/widgets/navigator.dart';
export 'src/widgets/nested_scroll_view.dart';
export 'src/widgets/notification_listener.dart';
export 'src/widgets/orientation_builder.dart';
export 'src/widgets/overlay.dart';
export 'src/widgets/overscroll_indicator.dart';
export 'src/widgets/page_storage.dart';
export 'src/widgets/page_view.dart';
export 'src/widgets/pages.dart';
export 'src/widgets/performance_overlay.dart';
export 'src/widgets/placeholder.dart';
export 'src/widgets/preferred_size.dart';
export 'src/widgets/primary_scroll_controller.dart';
export 'src/widgets/raw_keyboard_listener.dart';
export 'src/widgets/routes.dart';
export 'src/widgets/safe_area.dart';
export 'src/widgets/scroll_activity.dart';
export 'src/widgets/scroll_configuration.dart';
export 'src/widgets/scroll_context.dart';
export 'src/widgets/scroll_controller.dart';
export 'src/widgets/scroll_metrics.dart';
export 'src/widgets/scroll_notification.dart';
export 'src/widgets/scroll_physics.dart';
export 'src/widgets/scroll_position.dart';
export 'src/widgets/scroll_position_with_single_context.dart';
export 'src/widgets/scroll_simulation.dart';
export 'src/widgets/scroll_view.dart';
export 'src/widgets/scrollbar.dart';
export 'src/widgets/scrollable.dart';
export 'src/widgets/semantics_debugger.dart';
export 'src/widgets/single_child_scroll_view.dart';
export 'src/widgets/size_changed_layout_notifier.dart';
export 'src/widgets/sliver.dart';
export 'src/widgets/sliver_persistent_header.dart';
export 'src/widgets/sliver_prototype_extent_list.dart';
export 'src/widgets/spacer.dart';
export 'src/widgets/status_transitions.dart';
export 'src/widgets/table.dart';
export 'src/widgets/text.dart';
export 'src/widgets/text_selection.dart';
export 'src/widgets/ticker_provider.dart';
export 'src/widgets/title.dart';
export 'src/widgets/transitions.dart';
export 'src/widgets/unique_widget.dart';
export 'src/widgets/value_listenable_builder.dart';
export 'src/widgets/viewport.dart';
export 'src/widgets/visibility.dart';
export 'src/widgets/web_navigator.dart';
export 'src/widgets/widget_inspector.dart';
export 'src/widgets/will_pop_scope.dart';

/// Inflate the given widget and attach it to the screen.
///
/// The widget is given constraints during layout that force it to fill the
/// entire screen. If you wish to align your widget to one side of the screen
/// (e.g., the top), consider using the [Align] widget. If you wish to center
/// your widget, you can also use the [Center] widget
///
/// Calling [runApp] again will detach the previous root widget from the screen
/// and attach the given widget in its place. The new widget tree is compared
/// against the previous widget tree and any differences are applied to the
/// underlying render tree, similar to what happens when a [StatefulWidget]
/// rebuilds after calling [State.setState].
///
/// Initializes the binding using [WidgetsFlutterBinding] if necessary.
///
/// See also:
///
/// * [WidgetsBinding.attachRootWidget], which creates the root widget for the
///   widget hierarchy.
/// * [RenderObjectToWidgetAdapter.attachToRenderTree], which creates the root
///   element for the element hierarchy.
/// * [WidgetsBinding.handleBeginFrame], which pumps the widget pipeline to
///   ensure the widget, element, and render trees are all built.
void runApp(Widget app) {
  _ensureProductionBindingsInitialized();
  binding.runApp(app);
}

/// Initialize bindings, if they haven't been initialized yet.
void _ensureProductionBindingsInitialized() {
  if (binding.WidgetsBinding.instance != null) {
    return;
  }

  // Calling this getter to force the DOM renderer to initialize before we
  // initialize framework bindings.
  domRenderer;

  bool waitingForAnimation = false;
  ui.window.webOnlyScheduleFrameCallback = () {
    // We're asked to schedule a frame and call `frameHandler` when the frame
    // fires.
    if (!waitingForAnimation) {
      waitingForAnimation = true;
      html.window.requestAnimationFrame((num highResTime) {
        // Reset immediately, because `frameHandler` can schedule more frames.
        waitingForAnimation = false;

        // We have to convert high-resolution time to `int` so we can construct
        // a `Duration` out of it. However, high-res time is supplied in
        // milliseconds as a double value, with sub-millisecond information
        // hidden in the fraction. So we first multiply it by 1000 to uncover
        // microsecond precision, and only then convert to `int`.
        final highResTimeMicroseconds = (1000 * highResTime).toInt();
        ui.window
            .onBeginFrame(new Duration(microseconds: highResTimeMicroseconds));
        // TODO(yjbanov): technically Flutter flushes microtasks between
        //                onBeginFrame and onDrawFrame. We don't, which hasn't
        //                been an issue yet, but eventually we'll have to
        //                implement it properly.
        ui.window.onDrawFrame();
      });
    }
  };

  PointerBinding();
}
