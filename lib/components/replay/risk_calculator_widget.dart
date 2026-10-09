/// Risk Calculator Widget — interactive bottom sheet for computing
/// position size, risk amount, and R:R from account balance, risk %, and
/// entry/SL/TP prices.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/risk_calculator.dart';
import 'package:app/utils/haptics.dart';

class RiskCalculatorWidget extends StatefulWidget {
  final double accountBalance;
  final double entryPrice;
  final double? stopLossPrice;
  final double? takeProfitPrice;
  final bool isLong;

  /// Called when the user taps "Apply" with the calculated position size.
  final ValueChanged<RiskCalculation>? onApply;

  const RiskCalculatorWidget({
    super.key,
    required this.accountBalance,
    required this.entryPrice,
    this.stopLossPrice,
    this.takeProfitPrice,
    this.isLong = true,
    this.onApply,
  });

  @override
  State<RiskCalculatorWidget> createState() => _RiskCalculatorWidgetState();
}

class _RiskCalculatorWidgetState extends State<RiskCalculatorWidget> {
  late double _riskPercent;
  late TextEditingController _balanceController;
  late TextEditingController _slController;
  late TextEditingController _tpController;

  static const _presets = [0.5, 1.0, 2.0, 3.0];

  @override
  void initState() {
    super.initState();
    _riskPercent = 1.0;
    _balanceController = TextEditingController(
      text: widget.accountBalance.toStringAsFixed(0),
    );
    _slController = TextEditingController(
      text: widget.stopLossPrice?.toStringAsFixed(2) ?? '',
    );
    _tpController = TextEditingController(
      text: widget.takeProfitPrice?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _slController.dispose();
    _tpController.dispose();
    super.dispose();
  }

  RiskCalculation _compute() {
    final balance = double.tryParse(_balanceController.text) ?? widget.accountBalance;
    final sl = double.tryParse(_slController.text);
    final tp = double.tryParse(_tpController.text);

    if (sl == null || sl <= 0) return RiskCalculation.zero;

    return RiskCalculator.compute(
      accountBalance: balance,
      riskPercent: _riskPercent,
      entryPrice: widget.entryPrice,
      stopLossPrice: sl,
      takeProfitPrice: tp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final calc = _compute();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Position Size Calculator',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: colors.foreground),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Account Balance & Risk % row.
          Row(
            children: [
              Expanded(
                child: _InputField(
                  label: 'Account Balance',
                  suffix: 'USDT',
                  controller: _balanceController,
                  colors: colors,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk Per Trade',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (final preset in _presets) ...[
                          _PresetChip(
                            label: '${preset.toStringAsFixed(preset == preset.roundToDouble() ? 0 : 1)}%',
                            active: _riskPercent == preset,
                            onTap: () {
                              Haptics.selection();
                              setState(() => _riskPercent = preset);
                            },
                            colors: colors,
                          ),
                          if (preset != _presets.last)
                            const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Entry, SL, TP row.
          Row(
            children: [
              Expanded(
                child: _InfoCell(
                  label: 'Entry',
                  value: widget.entryPrice.toStringAsFixed(2),
                  color: colors.primary,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InputField(
                  label: 'Stop Loss',
                  controller: _slController,
                  colors: colors,
                  onChanged: (_) => setState(() {}),
                  textColor: colors.negative,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InputField(
                  label: 'Take Profit',
                  controller: _tpController,
                  colors: colors,
                  onChanged: (_) => setState(() {}),
                  textColor: colors.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Results grid.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ResultCell(
                        label: 'Position Size',
                        value: '\$${calc.positionSize.toStringAsFixed(2)}',
                        colors: colors,
                        highlight: true,
                      ),
                    ),
                    Expanded(
                      child: _ResultCell(
                        label: 'Quantity',
                        value: calc.quantity.toStringAsFixed(4),
                        colors: colors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ResultCell(
                        label: 'Risk Amount',
                        value: '-\$${calc.riskAmount.toStringAsFixed(2)}',
                        colors: colors,
                        valueColor: colors.negative,
                      ),
                    ),
                    Expanded(
                      child: _ResultCell(
                        label: 'Potential Reward',
                        value: calc.potentialReward > 0
                            ? '+\$${calc.potentialReward.toStringAsFixed(2)}'
                            : '—',
                        colors: colors,
                        valueColor: calc.potentialReward > 0 ? colors.positive : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ResultCell(
                        label: 'Risk:Reward',
                        value: calc.riskRewardRatio > 0
                            ? '1:${calc.riskRewardRatio.toStringAsFixed(2)}'
                            : '—',
                        colors: colors,
                        highlight: calc.riskRewardRatio >= 2.0,
                        valueColor: calc.riskRewardRatio >= 2.0 ? colors.positive : null,
                      ),
                    ),
                    Expanded(
                      child: _ResultCell(
                        label: 'Est. Fees',
                        value: '\$${calc.feeCost.toStringAsFixed(2)}',
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Apply button.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryForeground,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: calc.positionSize > 0
                  ? () {
                      Haptics.medium();
                      widget.onApply?.call(calc);
                      Navigator.pop(context);
                    }
                  : null,
              child: Text(
                'Apply Position Size (\$${calc.positionSize.toStringAsFixed(2)})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HELPER WIDGETS
// ============================================================

class _InputField extends StatelessWidget {
  final String label;
  final String? suffix;
  final TextEditingController controller;
  final ThemePalette colors;
  final ValueChanged<String>? onChanged;
  final Color? textColor;

  const _InputField({
    required this.label,
    this.suffix,
    required this.controller,
    required this.colors,
    this.onChanged,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor ?? colors.foreground,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              suffixText: suffix,
              suffixStyle: TextStyle(
                fontSize: 9,
                color: colors.mutedForeground,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.border.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: colors.background,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ThemePalette colors;

  const _InfoCell({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 34,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ThemePalette colors;

  const _PresetChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? colors.primary : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? colors.primary : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _ResultCell extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette colors;
  final bool highlight;
  final Color? valueColor;

  const _ResultCell({
    required this.label,
    required this.value,
    required this.colors,
    this.highlight = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: colors.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (highlight ? colors.primary : colors.foreground),
          ),
        ),
      ],
    );
  }
}
