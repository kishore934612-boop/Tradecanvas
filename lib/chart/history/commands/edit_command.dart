/// Command for editing text, style, lock, visibility, name, or properties of drawings/objects.
library;

import 'package:app/chart/history/chart_command.dart';
import 'package:app/models/drawing.dart';

class EditCommand implements ChartCommand {
  final Drawing beforeState;
  final Drawing afterState;
  final String actionLabel;
  final void Function(Drawing drawing) onUpdate;

  EditCommand({
    required this.beforeState,
    required this.afterState,
    required this.actionLabel,
    required this.onUpdate,
  });

  factory EditCommand.style({
    required Drawing before,
    required Drawing after,
    required void Function(Drawing drawing) onUpdate,
  }) {
    return EditCommand(
      beforeState: before,
      afterState: after,
      actionLabel: 'Change Style',
      onUpdate: onUpdate,
    );
  }

  factory EditCommand.lock({
    required Drawing before,
    required Drawing after,
    required bool locked,
    required void Function(Drawing drawing) onUpdate,
  }) {
    return EditCommand(
      beforeState: before,
      afterState: after,
      actionLabel: locked ? 'Lock' : 'Unlock',
      onUpdate: onUpdate,
    );
  }

  factory EditCommand.visibility({
    required Drawing before,
    required Drawing after,
    required bool visible,
    required void Function(Drawing drawing) onUpdate,
  }) {
    return EditCommand(
      beforeState: before,
      afterState: after,
      actionLabel: visible ? 'Show' : 'Hide',
      onUpdate: onUpdate,
    );
  }

  factory EditCommand.rename({
    required Drawing before,
    required Drawing after,
    required void Function(Drawing drawing) onUpdate,
  }) {
    return EditCommand(
      beforeState: before,
      afterState: after,
      actionLabel: 'Rename',
      onUpdate: onUpdate,
    );
  }

  @override
  String get description => '$actionLabel ${afterState.tool.label}';

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
