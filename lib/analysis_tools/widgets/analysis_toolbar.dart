/// Independent Smart Analysis Tools Toolbar component (Deprecated/Disabled per user request).
library;

import 'package:flutter/material.dart';

class AnalysisToolbar extends StatelessWidget {
  const AnalysisToolbar({
    super.key,
    required dynamic controller,
    required dynamic onSelectAnalysisTool,
    dynamic activeAnalysisTool,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/*
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final categorized = AnalysisToolDefinition.categorizedTools;
    final toolsInCat = categorized[_selectedCategory] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category selector chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: AnalysisCategory.values.map((cat) {
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('${cat.iconSymbol} ${cat.displayName}'),
                    selected: isSelected,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _selectedCategory = cat);
                    },
                    selectedColor: colors.primary.withValues(alpha: 0.2),
                    backgroundColor: colors.background,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: isSelected ? colors.primary : colors.mutedForeground,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: isSelected ? colors.primary : colors.border),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),

          // Tools list in active category
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.border.withValues(alpha: 0.4)),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: toolsInCat.map((def) {
                final isActive = widget.activeAnalysisTool == def.type;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: '${def.title}\n${def.description}',
                    child: InkWell(
                      onTap: () {
                        Haptics.selection();
                        if (isActive) {
                          widget.onSelectAnalysisTool(null);
                        } else {
                          widget.onSelectAnalysisTool(def.type);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive ? colors.primary.withValues(alpha: 0.18) : colors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? colors.primary : colors.border,
                            width: isActive ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(def.type.iconSymbol, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              def.type.shortLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isActive ? colors.primary : colors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
*/
