/// Wrapper forwarding StrategySettingsSheet calls to StrategyCustomizationScreen.
library;

import 'package:flutter/material.dart';

import 'package:app/models/strategy_type.dart';
import 'package:app/screens/strategy_customization_screen.dart';

class StrategySettingsSheet extends StatelessWidget {
  final StrategySettings settings;
  final ValueChanged<StrategySettings> onChanged;

  const StrategySettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StrategyCustomizationScreen(
      settings: settings,
      onChanged: onChanged,
    );
  }
}
