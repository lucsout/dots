import 'package:flutter/material.dart';

class DotWidget extends StatelessWidget {
  final Color color;
  DotWidget(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(width: 2, height: 2, color: color);
  }
}
