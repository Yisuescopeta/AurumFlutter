import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    PushNotificationService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
