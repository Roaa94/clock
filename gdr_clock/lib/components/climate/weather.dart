import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:gdr_clock/clock.dart';

class AnimatedWeather extends ImplicitlyAnimatedWidget {
  final ClockModel model;

  const AnimatedWeather({
    Key key,
    Curve curve = const ElasticInOutCurve(.6),
    Duration duration = const Duration(milliseconds: 942),
    this.model,
  }) : super(key: key, curve: curve, duration: duration);

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() {
    return _AnimatedWeatherState();
  }
}

class _AnimatedWeatherState extends AnimatedWidgetBaseState<AnimatedWeather> {
  Tween<double> _angle;

  double get _angleFromModel => 2 * pi / WeatherCondition.values.length * -WeatherCondition.values.indexOf(widget.model.weatherCondition);

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _angle = visitor(_angle, _angleFromModel, (value) => Tween<double>(begin: value));
  }

  @override
  Widget build(BuildContext context) {
    return Weather(
      angle: _angle?.evaluate(animation) ?? 0,
      textStyle: Theme.of(context).textTheme.body1,
      children: WeatherCondition.values.map((condition) => WeatherIcon(condition: condition)).toList(),
    );
  }
}

class Weather extends MultiChildRenderObjectWidget {
  final double angle;
  final TextStyle textStyle;

  Weather({
    Key key,
    @required List<Widget> children,
    @required this.angle,
    @required this.textStyle,
  })  : assert(angle != null),
        assert(textStyle != null),
        super(key: key, children: children);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderWeather(angle: angle, textStyle: textStyle);
  }

  @override
  void updateRenderObject(BuildContext context, RenderWeather renderObject) {
    renderObject
      ..angle = angle
      ..textStyle = textStyle
      ..markNeedsPaint();
  }
}

class WeatherChildrenParentData extends CompositionChildrenParentData<WeatherCondition> {
  /// Indicates where the icon has its center point, i.e. where the hand points to.
  Offset center;

  double rotationAngle;
}

class RenderWeather extends RenderComposition<WeatherCondition, WeatherChildrenParentData, Weather> {
  RenderWeather({
    this.angle,
    this.textStyle,
  }) : super(WeatherCondition.values);

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! WeatherChildrenParentData) {
      child.parentData = WeatherChildrenParentData()..valid = false;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);

    final clockCompositionData = parentData as ClockChildrenParentData;

    clockCompositionData
      ..childType = ClockComponent.weather
      ..valid = true;
  }

  double angle;
  TextStyle textStyle;

  double _radius;

  List<WeatherCondition> get conditions => children;

  @override
  void performLayout() {
    super.performLayout();

    size = constraints.biggest;

    _radius = size.width / 2;

    var angle = 0.0;
    for (final condition in conditions) {
      final child = layoutChildren[condition], childParentData = layoutParentData[condition];

      const indentFactor = .16;

      // Give the icons the full area and make them position themselves correctly and not paint over other children in their paint method.
      childParentData
        ..offset = Offset.zero
        ..center = (Offset.zero & size).center + Offset.fromDirection(angle, _radius * (1 - indentFactor))
        ..rotationAngle = angle;
      child.layout(BoxConstraints.tight(size), parentUsesSize: false);

      angle += 2 * pi / conditions.length;
    }
  }

  static const arrowColor = Color(0xffffddbb);

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);

    final canvas = context.canvas;

    canvas.save();
    // Translate the canvas to the center of the square.
    canvas.translate(offset.dx + size.width / 2, offset.dy + size.height / 2);

    // Save the initial rotation in order to always draw the arrow pointing straight up.
    canvas.save();
    // Rotate the disc by the given angle.
    canvas.rotate(angle);

    canvas.drawOval(Rect.fromCircle(center: Offset.zero, radius: _radius), Paint()..color = const Color(0xff3c9aff));

    // todo use children instead
    final divisions = WeatherCondition.values.length;
    for (final condition in WeatherCondition.values) {
      final painter = TextPainter(text: TextSpan(text: '$condition', style: textStyle), textDirection: TextDirection.ltr);
      painter.layout();
      painter.paint(
          canvas,
          Offset(
              -painter.width / 2,
              -size.height / 2 +
                  // Push the text inwards a bit.
                  32.79));

      canvas.rotate(2 * pi / divisions);
    }

    // Restore initial rotation.
    canvas.restore();

    // Draw tip of the arrow pointing up.
    final h = -size.height / 3.4, s = 13.42;
    canvas.drawPath(
        Path()
          // Remember that this is the center of the circle.
          ..moveTo(0, h)
          ..lineTo(-s, h)
          ..lineTo(0, h - s)
          ..lineTo(s, h)
          ..lineTo(0, h)
          ..close(),
        Paint()
          ..color = arrowColor
          ..style = PaintingStyle.fill);
    // Draw the rest of the arrow.
    canvas.drawLine(
        Offset.zero,
        Offset(0, h),
        Paint()
          ..color = arrowColor
          ..strokeWidth = 5.2
          ..strokeCap = StrokeCap.round);

    canvas.restore();
  }
}

class WeatherIcon extends LeafRenderObjectWidget {
  final WeatherCondition condition;

  WeatherIcon({
    Key key,
    @required this.condition,
  })  : assert(condition != null),
        super(key: key);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderWeatherIcon(
      condition: condition,
    );
  }
}

class RenderWeatherIcon extends RenderCompositionChild<WeatherCondition, WeatherChildrenParentData> {
  RenderWeatherIcon({
    WeatherCondition condition,
  }) : super(condition);

  WeatherCondition get condition => childType;

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Clip the area of the parent (weather circle).
    context.pushClipPath(needsCompositing, offset, offset & size, Path()..addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2)), (context, offset) {
      // Position and rotate the canvas according to the values stored in the composition data.
      context.pushTransform(needsCompositing, offset, Matrix4.translationValues(compositionData.center.dx, compositionData.center.dy, 0)..rotateZ(compositionData.rotationAngle), paintIcon);
    });
  }

  void paintIcon(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    switch (condition) {
      case WeatherCondition.cloudy:
        paintCloudy(canvas);
        break;
      case WeatherCondition.foggy:
        paintFoggy(canvas);
        break;
      case WeatherCondition.rainy:
        paintRainy(canvas);
        break;
      case WeatherCondition.snowy:
        paintSnowy(canvas);
        break;
      case WeatherCondition.sunny:
        paintSunny(canvas);
        break;
      case WeatherCondition.thunderstorm:
        paintThunderstorm(canvas);
        break;
      case WeatherCondition.windy:
        paintWindy(canvas);
        break;
    }
  }

  void paintCloudy(Canvas canvas) {
    canvas.drawOval(Rect.fromCircle(center: Offset.zero, radius: 50), Paint());
  }

  void paintFoggy(Canvas canvas) {
    // Test clipping.
    canvas.drawPaint(Paint()..color = const Color(0xffffa597));
  }

  void paintRainy(Canvas canvas) {}

  void paintSnowy(Canvas canvas) {}

  void paintSunny(Canvas canvas) {}

  void paintThunderstorm(Canvas canvas) {}

  void paintWindy(Canvas canvas) {}
}