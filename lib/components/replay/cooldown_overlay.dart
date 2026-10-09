/// Cooldown Overlay — full-screen overlay shown when a discipline
/// guardrail is violated, blocking further trades until the user takes action.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/discipline_guardrails.dart';
import 'package:app/utils/haptics.dart';

class CooldownOverlay extends StatelessWidget {
  final GuardrailViolation violation;
  final double drawdownPercent;
  final int consecutiveLosses;
  final int totalTrades;
  final int maxTrades;
  final double sessionPnl;
  final int wins;
  final int losses;
  final VoidCallback onReviewTrades;
  final VoidCallback onResetSession;

  const CooldownOverlay({
    super.key,
    required this.violation,
    required this.drawdownPercent,
    required this.consecutiveLosses,
    required this.totalTrades,
    required this.maxTrades,
    required this.sessionPnl,
    required this.wins,
    required this.losses,
    required this.onReviewTrades,
    required this.onResetSession,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.destructive.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.destructive.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon.
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.destructive.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Text(
                    violation.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title.
              Text(
                violation.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.destructive,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Message.
              Text(
                DisciplineGuardrails.getViolationMessage(
                  violation,
                  drawdownPercent: drawdownPercent,
                  consecutiveLosses: consecutiveLosses,
                  totalTrades: totalTrades,
                  maxTrades: maxTrades,
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.foreground,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Session stats summary.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      label: 'Win Rate',
                      value: totalTrades > 0
                          ? '${(wins / totalTrades * 100).toStringAsFixed(0)}%'
                          : '—',
                      colors: colors,
                    ),
                    _StatColumn(
                      label: 'Net P&L',
                      value: '${sessionPnl >= 0 ? "+" : ""}\$${sessionPnl.toStringAsFixed(2)}',
                      colors: colors,
                      valueColor:
                          sessionPnl >= 0 ? colors.positive : colors.negative,
                    ),
                    _StatColumn(
                      label: 'Trades',
                      value: '$totalTrades',
                      colors: colors,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Motivational tip.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  DisciplineGuardrails.getViolationTip(violation),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.foreground,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.assessment_rounded, size: 16),
                      label: const Text(
                        'Review Trades',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        Haptics.selection();
                        onReviewTrades();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.destructive,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text(
                        'Reset Session',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        Haptics.vibrate();
                        onResetSession();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette colors;
  final Color? valueColor;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: colors.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? colors.foreground,
          ),
        ),
      ],
    );
  }
}
