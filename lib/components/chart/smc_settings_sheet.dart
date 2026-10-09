/// Wrapper forwarding SmcSettingsSheet calls to SmcCustomizationScreen.
library;

import 'package:flutter/material.dart';

import 'package:app/models/smc_type.dart';
import 'package:app/screens/smc_customization_screen.dart';

class SmcSettingsSheet extends StatelessWidget {
  final SmcSettings settings;
  final ValueChanged<SmcSettings> onChanged;

  const SmcSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SmcCustomizationScreen(
      settings: settings,
      onChanged: onChanged,
    );
  }
}
