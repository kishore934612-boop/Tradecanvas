/// Custom Painter integration layer for Smart Analysis rendering.
library;

import 'package:flutter/material.dart';

import 'package:app/analysis_tools/engine/analysis_renderer.dart';
import 'package:app/analysis_tools/engine/analysis_serializer.dart';
import 'package:app/components/chart/chart_layout.dart';
import 'package:app/components/chart/chart_transform.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/drawing.dart';

class AnalysisPainter {
  /// Paint analysis metadata overlays for a given drawing if it possesses analysis metadata.
  static void paintIfAnalysis(
    Canvas canvas,
    Drawing drawing,
    ChartTransform transform,
    ChartLayout layout, {
    required ThemePalette colors,
    bool isSelected = false,
    bool isPreview = false,
  }) {
    final metadata = AnalysisSerializer.decodeMetadata(drawing);
    if (metadata == null) return;

    AnalysisRenderer.render(
      canvas,
      drawing,
      metadata,
      transform,
      layout,
      colors: colors,
      isSelected: isSelected,
      isPreview: isPreview,
    );
  }
}
