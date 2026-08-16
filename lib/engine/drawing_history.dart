/// Per-symbol drawing history stack.
///
/// Every mutation (add, delete, move, restyle, clear) pushes a [DrawingEdit]
/// that knows how to undo and redo itself. This replaces the previous
/// single-level "last deletion only" undo with a full stack, kept separately
/// per symbol so switching charts does not bleed one symbol's history into
/// another's.
library;

import 'package:app/models/drawing.dart';

/// One reversible change to a symbol's drawing set.
///
/// [before]/[after] hold the full drawing state on either side of the edit
/// (not deltas) — the drawing set per symbol is small (a handful to a few
/// dozen shapes), so snapshotting is simpler and safer than diffing, and
/// costs nothing noticeable.
class DrawingEdit {
  final String symbol;
  final List<Drawing> before;
  final List<Drawing> after;
  final String description;

  const DrawingEdit({
    required this.symbol,
    required this.before,
    required this.after,
    required this.description,
  });
}

/// Undo/redo stack for a single symbol.
///
/// Standard editor semantics: undoing then making a new edit discards the
/// redo branch, since there is nowhere for it to reattach to.
class DrawingHistory {
  final List<DrawingEdit> _undoStack = [];
  final List<DrawingEdit> _redoStack = [];

  /// Cap so a very long session cannot grow this unboundedly.
  static const int maxDepth = 100;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String? get nextUndoDescription =>
      _undoStack.isEmpty ? null : _undoStack.last.description;
  String? get nextRedoDescription =>
      _redoStack.isEmpty ? null : _redoStack.last.description;

  void push(DrawingEdit edit) {
    _undoStack.add(edit);
    if (_undoStack.length > maxDepth) _undoStack.removeAt(0);
    // A fresh edit invalidates whatever was available to redo.
    _redoStack.clear();
  }

  /// Pop the most recent edit and return the state to restore ([before]).
  DrawingEdit? undo() {
    if (_undoStack.isEmpty) return null;
    final edit = _undoStack.removeLast();
    _redoStack.add(edit);
    return edit;
  }

  /// Pop the most recently undone edit and return the state to restore
  /// ([after]).
  DrawingEdit? redo() {
    if (_redoStack.isEmpty) return null;
    final edit = _redoStack.removeLast();
    _undoStack.add(edit);
    return edit;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
