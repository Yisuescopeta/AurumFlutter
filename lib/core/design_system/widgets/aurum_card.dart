import 'package:flutter/material.dart';

import '../app_tokens.dart';

class AurumCard extends StatelessWidget {
  const AurumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.slate100),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 10),
            color: Color(0x13000000),
          ),
        ],
      ),
      child: child,
    );

    if (margin == null) return content;
    return Padding(padding: margin!, child: content);
  }
}
