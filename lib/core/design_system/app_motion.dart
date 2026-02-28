import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration micro = Duration(milliseconds: 160);
  static const Duration short = Duration(milliseconds: 240);
  static const Duration medium = Duration(milliseconds: 340);
  static const Duration long = Duration(milliseconds: 460);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;
}
