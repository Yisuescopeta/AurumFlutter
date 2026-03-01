import 'package:flutter/material.dart';

class AppAdaptive {
  AppAdaptive._();

  static bool reduceMotion(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  static Duration motionDuration(BuildContext context, Duration normal) {
    return reduceMotion(context) ? const Duration(milliseconds: 120) : normal;
  }
}
