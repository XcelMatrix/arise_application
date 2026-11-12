import 'package:flutter/material.dart';

/// App bar leading widget: a back arrow when there is a page to go back to,
/// otherwise the ARISE logo (the main tab pages).
class BackOrLogo extends StatelessWidget {
  const BackOrLogo({super.key});

  @override
  Widget build(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      return IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.asset("assets/icons/icon_white.png", width: 48, height: 48),
    );
  }
}
