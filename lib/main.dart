import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:render_metrics/render_metrics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:async/async.dart';

import 'dart:math';

import 'dot_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class AnimationDot {
  Offset coords;
  AnimationController controller;
  bool reverse;

  CancelableOperation? delay;

  AnimationDot(this.coords, this.controller, this.reverse, {this.delay});
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  bool hasTapped = false;

  double spacingFrom = 8;
  double spacingTo = 10;

  double widthGrid = 400;
  double heightGrid = 400;
  int rows = 30;
  int columns = 30;
  double dotSize = 2;

  double paddingSmallGrid = 80;

  double horSpacing = 0;
  double verSpacing = 0;

  double horSpacingFrom = 0;
  double verSpacingFrom = 0;

  double clickedX = 0;
  double clickedY = 0;

  final renderManager = RenderParametersManager<dynamic>();

  List<AnimationDot> controllers = [];

  Future? delayed;
  @override
  void initState() {
    super.initState();

    horSpacingFrom =
        ((widthGrid - (paddingSmallGrid * 2)) - (dotSize * columns)) /
            (columns - 1);
    verSpacingFrom =
        ((heightGrid - (paddingSmallGrid * 2)) - (dotSize * rows)) / (rows - 1);

    horSpacing = (widthGrid - (dotSize * columns)) / (columns - 1);
    verSpacing = (heightGrid - (dotSize * rows)) / (rows - 1);

    print("Number of rows: $rows");
    print("Number of columns: $columns");
    print("Horizontal spacing between dots: $horSpacing");
    print("Vertical spacing between dots: $verSpacing");

    delayed = Future.delayed(const Duration(milliseconds: 1000));
  }

  double calcDelay(int row, int col) {
    var clickedLocalX = clickedX;
    var clickedLocalY = clickedY;

    double xDot = (col * horSpacing) + (2 * row);
    double yDot = (row * verSpacing) + (2 * row);

    var distance =
        sqrt(pow(clickedLocalX - xDot, 2) + pow(clickedLocalY - yDot, 2));

    Random random = Random();
    var rand = random.nextDouble();

    return (distance * 5) + (rand * 20);
  }

  Widget buildDot(int totalRows, int totalColumns, int index, double horSpacing,
      double verSpacing, bool placeholder) {
    int row = index ~/ totalColumns;
    int col = index % totalColumns;

    var topStart = (verSpacing * row.toDouble()) +
        (placeholder ? 0 : paddingSmallGrid) +
        (2 * row);

    var leftStart = (horSpacing * col.toDouble()) +
        (placeholder ? 0 : paddingSmallGrid) +
        (2 * col);

    var controller = AnimationController.unbounded(
        vsync: this, duration: const Duration(milliseconds: 250));

    controllers.add(AnimationDot(
        Offset(row.toDouble(), col.toDouble()), controller, false));

    var widget = !placeholder
        ? DotWidget(Colors.white)
        : RenderMetricsObject(
            id: '${index}_PLACEHOLDER',
            manager: renderManager,
            child: DotWidget(Colors.transparent),
          );

    if (placeholder) {
      return Positioned(
          top: topStart, left: leftStart, width: 2, height: 2, child: widget);
    } else {
      return AnimatedBuilder(
          animation: controller,
          child: widget,
          builder: (_, child) {
            var topValue = topStart;
            var leftValue = leftStart;
            if (!placeholder) {
              var box = renderManager.getRenderData('${index}_PLACEHOLDER');

              if (box != null) {
                var transformToRelativeY =
                    (MediaQuery.of(context).size.height / 2) - (heightGrid / 2);
                var transformToRelativeX =
                    (MediaQuery.of(context).size.width / 2) - (widthGrid / 2);

                topValue = lerpDouble(topStart,
                    box.topLeft.y - transformToRelativeY, controller.value)!;
                leftValue = lerpDouble(leftStart,
                    box.topLeft.x - transformToRelativeX, controller.value)!;
              }
            }

            return Positioned(
                top: topValue,
                left: leftValue,
                width: 2,
                height: 2,
                child: child!);
          });
    }
  }

  void tapped(TapDownDetails details) async {
    print(details.localPosition);

    clickedX = details.localPosition.dx;
    clickedY = details.localPosition.dy;

    for (var dot in controllers) {
      if (dot.controller.value == 0) dot.controller.stop();

      dot.reverse = false;
    }

    for (var dot in controllers) {
      var spring = SpringDescription.withDampingRatio(
          mass: 0.95, stiffness: 100, ratio: 0.65);

      final simulation = SpringSimulation(spring, dot.controller.value, 1, 1);

      dot.delay = CancelableOperation.fromFuture(Future.delayed(
          (calcDelay(dot.coords.dx.toInt(), dot.coords.dy.toInt()) +
                  Random().nextDouble() * 500)
              .ms));

      dot.delay!.value.then((value) {
        if (!dot.reverse) {
          dot.controller.animateWith(simulation);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTapDown: (details) => tapped(details),
                onTapUp: (details) {
                  for (var dot in controllers) {
                    if (dot.controller.value == 0) dot.controller.stop();

                    dot.reverse = true;

                    if (dot.delay != null) dot.delay!.cancel();

                    var spring = SpringDescription.withDampingRatio(
                        mass: 0.95, stiffness: 100, ratio: 0.65);

                    final simulation =
                        SpringSimulation(spring, dot.controller.value, 0, 0);

                    if (dot.reverse) {
                      dot.controller.animateWith(simulation);
                    }
                  }
                },
                child: Container(
                    width: widthGrid,
                    height: heightGrid,
                    color: Colors.black87,
                    child: Stack(
                      children: [
                        ...List.generate(
                            rows * columns,
                            (index) => buildDot(rows, columns, index,
                                horSpacingFrom, verSpacingFrom, false)),
                        ...List.generate(
                            rows * columns,
                            (index) => buildDot(rows, columns, index,
                                horSpacing, verSpacing, true))
                      ],
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
