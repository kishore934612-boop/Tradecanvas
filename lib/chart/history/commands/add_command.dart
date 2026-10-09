/// Command for adding a new drawing or position tool to the chart.
library;

import 'package:app/chart/history/chart_command.dart';
import 'package:app/models/drawing.dart';

class AddCommand implements ChartCommand {
  final Drawing drawing;
  final void Function(Drawing drawing) onAdd;
  final void Function(String id) onDelete;

  AddCommand({
    required this.drawing,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  String get description => 'Add ${drawing.tool.label}';

  @override
  Future<void> execute() async {
    onAdd(drawing);
  }

  @override
  Future<void> undo() async {
    onDelete(drawing.id);
  }

  @override
  Future<void> redo() async {
    onAdd(drawing);
  }
}
