import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AurumAppBarTitle extends StatelessWidget {
  const AurumAppBarTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.appBarBrandTitleStyle(context),
    );
  }
}
