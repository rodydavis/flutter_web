// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'canvas.dart';
import 'geometry.dart';
import 'recording_canvas.dart';

/// Converts [path] to SVG path syntax to be used as "d" attribute in path
/// element.
void pathToSvg(Path path, StringBuffer sb) {
  for (Subpath subPath in path.subpaths) {
    for (PathCommand command in subPath.commands) {
      switch (command.type) {
        case PathCommandTypes.moveTo:
          MoveTo moveTo = command;
          sb.write('M ${moveTo.x} ${moveTo.y}');
          break;
        case PathCommandTypes.lineTo:
          LineTo lineTo = command;
          sb.write('L ${lineTo.x} ${lineTo.y}');
          break;
        case PathCommandTypes.bezierCurveTo:
          BezierCurveTo curve = command;
          sb.write('C ${curve.x1} ${curve.y1} '
              '${curve.x2} ${curve.y2} ${curve.x3} ${curve.y3}');
          break;
        case PathCommandTypes.quadraticCurveTo:
          QuadraticCurveTo quadraticCurveTo = command;
          sb.write('Q ${quadraticCurveTo.x1} ${quadraticCurveTo.y1} '
              '${quadraticCurveTo.x2} ${quadraticCurveTo.y2}');
          break;
        case PathCommandTypes.close:
          sb.write('Z');
          break;
        case PathCommandTypes.ellipse:
          Ellipse ellipse = command;
          _writeEllipse(
              sb,
              ellipse.x,
              ellipse.y,
              ellipse.radiusX,
              ellipse.radiusY,
              ellipse.rotation,
              ellipse.startAngle,
              ellipse.endAngle,
              ellipse.anticlockwise);
          break;
        case PathCommandTypes.rRect:
          RRectCommand rrectCommand = command;
          RRect rrect = rrectCommand.rrect;
          var left = rrect.left;
          var right = rrect.right;
          var top = rrect.top;
          var bottom = rrect.bottom;
          if (left > right) {
            left = right;
            right = rrect.left;
          }
          if (top > bottom) {
            top = bottom;
            bottom = rrect.top;
          }
          var trRadiusX = rrect.trRadiusX.abs();
          var tlRadiusX = rrect.tlRadiusX.abs();
          var trRadiusY = rrect.trRadiusY.abs();
          var tlRadiusY = rrect.tlRadiusY.abs();
          var blRadiusX = rrect.blRadiusX.abs();
          var brRadiusX = rrect.brRadiusX.abs();
          var blRadiusY = rrect.blRadiusY.abs();
          var brRadiusY = rrect.brRadiusY.abs();

          sb.write('L ${left + trRadiusX} $top ');
          // Top side and top-right corner
          sb.write('M ${right - trRadiusX} $top ');
          _writeEllipse(sb, right - trRadiusX, top + trRadiusY, trRadiusX,
              trRadiusY, 0, 1.5 * math.pi, 2.0 * math.pi, false);
          // Right side and bottom-right corner
          sb.write('L $right ${bottom - brRadiusY} ');
          _writeEllipse(sb, right - brRadiusX, bottom - brRadiusY, brRadiusX,
              brRadiusY, 0, 0, 0.5 * math.pi, false);
          // Bottom side and bottom-left corner
          sb.write('L ${left + blRadiusX} $bottom ');
          _writeEllipse(sb, left + blRadiusX, bottom - blRadiusY, blRadiusX,
              blRadiusY, 0, 0.5 * math.pi, math.pi, false);
          // Left side and top-left corner
          sb.write('L $left ${top + tlRadiusY} ');
          _writeEllipse(
            sb,
            left + tlRadiusX,
            top + tlRadiusY,
            tlRadiusX,
            tlRadiusY,
            0,
            math.pi,
            1.5 * math.pi,
            false,
          );
          break;
        case PathCommandTypes.rect:
          RectCommand rectCommand = command;
          bool horizontalSwap = rectCommand.width < 0;
          final left = horizontalSwap
              ? rectCommand.x - rectCommand.width
              : rectCommand.x;
          final width = horizontalSwap ? -rectCommand.width : rectCommand.width;
          bool verticalSwap = rectCommand.height < 0;
          final top =
              verticalSwap ? rectCommand.y - rectCommand.height : rectCommand.y;
          final height =
              verticalSwap ? -rectCommand.height : rectCommand.height;
          sb.write('M $left $top ');
          sb.write('L ${left + width} $top ');
          sb.write('L ${left + width} ${top + height} ');
          sb.write('L $left ${top + height} ');
          sb.write('L $left $top ');
          break;
        default:
          throw new UnimplementedError('Unknown path command $command');
      }
    }
  }
}

// See https://www.w3.org/TR/SVG/implnote.html B.2.3. Conversion from center to
// endpoint parameterization.
void _writeEllipse(
    StringBuffer sb,
    double cx,
    double cy,
    double radiusX,
    double radiusY,
    double rotation,
    double startAngle,
    double endAngle,
    bool antiClockwise) {
  double cosRotation = math.cos(rotation);
  double sinRotation = math.sin(rotation);
  double x = math.cos(startAngle) * radiusX;
  double y = math.sin(startAngle) * radiusY;

  double startPx = cx + (cosRotation * x - sinRotation * y);
  double startPy = cy + (sinRotation * x + cosRotation * y);

  double xe = math.cos(endAngle) * radiusX;
  double ye = math.sin(endAngle) * radiusY;

  double endPx = cx + (cosRotation * xe - sinRotation * ye);
  double endPy = cy + (sinRotation * xe + cosRotation * ye);

  double delta = endAngle - startAngle;
  bool largeArc = delta.abs() > math.pi;

  double rotationDeg = rotation / math.pi * 180.0;
  sb.write('M $startPx $startPy A $radiusX $radiusY ${rotationDeg} '
      '${largeArc ? 1 : 0} ${antiClockwise ? 0 : 1} $endPx $endPy');
}
