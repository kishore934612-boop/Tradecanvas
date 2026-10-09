import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:app/chart/history/chart_command.dart';

class HistoryManager extends ChangeNotifier {
  final int maxCapacity;
  final List<ChartCommand> _undoStack = [];
  final List<ChartCommand> _redoStack = [];

  HistoryManager({this.maxCapacity = 100});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  String? get nextUndoDescription =>
      _undoStack.isNotEmpty ? _undoStack.last.description : null;
  String? get nextRedoDescription =>
      _redoStack.isNotEmpty ? _redoStack.last.description : null;

  /// Execute a new command, append to undo stack and clear redo stack.
  Future<void> executeCommand(ChartCommand command) async {
    await command.execute();

    _undoStack.add(command);
    if (_undoStack.length > maxCapacity) {
      _undoStack.removeAt(0); // Evict oldest
    }
    _redoStack.clear();
    notifyListeners();
  }

  /// Push an already executed command into history stack without executing it again.
  void registerExecutedCommand(ChartCommand command) {
    _undoStack.add(command);
    if (_undoStack.length > maxCapacity) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    notifyListeners();
  }

  /// Perform Undo operation
  Future<bool> undo() async {
    if (!canUndo) return false;
    final cmd = _undoStack.removeLast();
    await cmd.undo();
    _redoStack.add(cmd);
    notifyListeners();
    return true;
  }

  /// Perform Redo operation
  Future<bool> redo() async {
    if (!canRedo) return false;
    final cmd = _redoStack.removeLast();
    await cmd.redo();
    _undoStack.add(cmd);
    notifyListeners();
    return true;
  }

  /// Clear history stack
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  /// Handle keyboard shortcuts (Ctrl+Z for Undo, Ctrl+Shift+Z or Ctrl+Y for Redo)
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isControlPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (isShiftPressed) {
        if (canRedo) {
          redo();
          return KeyEventResult.handled;
        }
      } else {
        if (canUndo) {
          undo();
          return KeyEventResult.handled;
        }
      }
    } else if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyY) {
      if (canRedo) {
        redo();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
