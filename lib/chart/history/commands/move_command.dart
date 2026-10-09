/// Command for moving shape position, handles, or anchors.
library;

import 'package:app/chart/history/chart_command.dart';
import 'package:app/models/drawing.dart';

class MoveCommand implements ChartCommand {
  final Drawing beforeState;
  final Drawing afterState;
  final void Function(Drawing drawing) onUpdate;

  MoveCommand({
    required this.beforeState,
    required this.afterState,
    required this.onUpdate,
  });

  @override
  String get description => 'Move ${afterState.tool.label}';

  @override
  Future<void> execute() async {
    onUpdate(afterState);
  }

  @override
  Future<void> undo() async {
    onUpdate(beforeState);
  }

  @override
  Future<void> redo() async {
    onUpdate(afterState);
  }
}
