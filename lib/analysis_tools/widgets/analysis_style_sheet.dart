/// Style and Metadata Customization Sheet for Smart Analysis tools.
library;

import 'package:flutter/material.dart';

import 'package:app/analysis_tools/models/analysis_object.dart';
import 'package:app/constants/colors.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/utils/haptics.dart';

class AnalysisStyleSheet extends StatefulWidget {
  final AnalysisObject object;
  final DrawingController controller;

  const AnalysisStyleSheet({
    super.key,
    required this.object,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required AnalysisObject object,
    required DrawingController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnalysisStyleSheet(
        object: object,
        controller: controller,
      ),
    );
  }

  @override
  State<AnalysisStyleSheet> createState() => _AnalysisStyleSheetState();
}

class _AnalysisStyleSheetState extends State<AnalysisStyleSheet> {
  late int _selectedColor;
  late double _fillOpacity;
  late String _label;
  late String _notes;
  late bool _mitigated;
  late bool _confirmed;
  late bool _invalidated;

  @override
  void initState() {
    super.initState();
    final meta = widget.object.metadata;
    final drawing = widget.object.drawing;
    _selectedColor = drawing.colorValue;
    _fillOpacity = (meta.style['fillOpacity'] as num?)?.toDouble() ?? meta.analysisType.defaultFillOpacity;
    _label = meta.label;
    _notes = meta.notes ?? '';
    _mitigated = meta.mitigated;
    _confirmed = meta.confirmed;
    _invalidated = meta.invalidated;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.70,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.mutedForeground.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(widget.object.metadata.analysisType.iconSymbol, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Style: ${widget.object.metadata.analysisType.displayName}',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: colors.mutedForeground),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Color Picker
                Text('Primary Color', style: TextStyle(color: colors.foreground, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final argb in kDrawingColors)
                      InkWell(
                        onTap: () {
                          Haptics.light();
                          setState(() => _selectedColor = argb);
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(argb),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == argb ? colors.foreground : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Fill Opacity slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fill Opacity', style: TextStyle(color: colors.foreground, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${(_fillOpacity * 100).round()}%', style: TextStyle(color: colors.mutedForeground, fontSize: 12)),
                  ],
                ),
                Slider(
                  value: _fillOpacity,
                  min: 0.05,
                  max: 0.90,
                  divisions: 17,
                  activeColor: Color(_selectedColor),
                  onChanged: (v) => setState(() => _fillOpacity = v),
                ),

                const SizedBox(height: 16),

                // Domain attributes
                Text('Status & Conditions', style: TextStyle(color: colors.foreground, fontSize: 13, fontWeight: FontWeight.w600)),
                SwitchListTile(
                  title: Text('Mitigated', style: TextStyle(color: colors.foreground, fontSize: 13)),
                  subtitle: Text('Cross out label when level is touched/filled', style: TextStyle(color: colors.mutedForeground, fontSize: 11)),
                  value: _mitigated,
                  onChanged: (v) => setState(() => _mitigated = v),
                  activeThumbColor: colors.primary,
                  dense: true,
                ),
                SwitchListTile(
                  title: Text('Confirmed', style: TextStyle(color: colors.foreground, fontSize: 13)),
                  subtitle: Text('Mark as validated high-probability level', style: TextStyle(color: colors.mutedForeground, fontSize: 11)),
                  value: _confirmed,
                  onChanged: (v) => setState(() => _confirmed = v),
                  activeThumbColor: colors.primary,
                  dense: true,
                ),
                SwitchListTile(
                  title: Text('Invalidated', style: TextStyle(color: colors.foreground, fontSize: 13)),
                  subtitle: Text('Mark as broken or failed zone', style: TextStyle(color: colors.mutedForeground, fontSize: 11)),
                  value: _invalidated,
                  onChanged: (v) => setState(() => _invalidated = v),
                  activeThumbColor: colors.negative,
                  dense: true,
                ),
              ],
            ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _save,
              child: const Text('Apply Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    Haptics.light();
    final meta = widget.object.metadata.copyWith(
      label: _label,
      notes: _notes,
      mitigated: _mitigated,
      confirmed: _confirmed,
      invalidated: _invalidated,
      style: {
        ...widget.object.metadata.style,
        'color': _selectedColor,
        'fillColor': Color(_selectedColor).withValues(alpha: _fillOpacity).toARGB32(),
        'fillOpacity': _fillOpacity,
      },
    );

    final updatedDrawing = widget.object.copyWith(metadata: meta).toDrawing();
    widget.controller.updateDrawing(updatedDrawing);
    Navigator.of(context).pop();
  }
}
