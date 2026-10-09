/// Command pattern base class for undoable/redoable chart actions.
library;

abstract class ChartCommand {
  /// Unique identifier or descriptive label for the command action.
  String get description;

  /// Execute the command for the first time.
  Future<void> execute();

  /// Revert the action performed by execute.
  Future<void> undo();

  /// Re-apply the action after an undo.
  Future<void> redo();
}
