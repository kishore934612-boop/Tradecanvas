/// Command for deleting single or multiple drawings/tools.
library;

import 'package:app/chart/history/chart_command.dart';
import 'package:app/models/drawing.dart';

class DeleteCommand implements ChartCommand {
  final List<Drawing> deletedDrawings;
  final void Function(List<Drawing> drawings) onRestore;
  final void Function(List<String> ids) onDelete;

  DeleteCommand({
    required this.deletedDrawings,
    required this.onRestore,
    required this.onDelete,
  });

  factory DeleteCommand.single({
    required Drawing drawing,
    required void Function(List<Drawing> drawings) onRestore,
    required void Function(List<String> ids) onDelete,
  }) {
    return DeleteCommand(
      deletedDrawings: [drawing],
      onRestore: onRestore,
      onDelete: onDelete,
    );
  }

  @override
  String get description {
    if (deletedDrawings.length == 1) {
      return 'Delete ${deletedDrawings.first.tool.label}';
    }
    return 'Delete ${deletedDrawings.length} items';
  }

  @override
  Future<void> execute() async {
    onDelete(deletedDrawings.map((d) => d.id).toList());
  }

  @override
  Future<void> undo() async {
    onRestore(deletedDrawings);
  }

  @override
  Future<void> redo() async {
    onDelete(deletedDrawings.map((d) => d.id).toList());
  }
}
