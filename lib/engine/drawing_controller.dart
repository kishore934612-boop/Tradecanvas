/// Drawing Controller — owns the drawing set for the chart.
///
/// Holds drawings per symbol, tracks the active tool and the shape currently
/// being placed, and persists changes. It stays free of pixel math: the chart
/// widget owns the data↔pixel transform and reports hits back here by id.
///
/// Every mutation is undoable/redoable via a full per-symbol history stack
/// ([DrawingHistory]) rather than a single "last deleted item" — see
/// drawing_history.dart.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app/analysis_tools/engine/analysis_tool_factory.dart';
import 'package:app/analysis_tools/models/analysis_type.dart';
import 'package:app/chart/history/history_manager.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/engine/drawing_history.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/engine/magnetic_snap.dart';
import 'package:app/models/drawing.dart';
import 'package:app/models/indicator_style.dart';

/// Default palette offered in the drawing toolbar.
const List<int> kDrawingColors = [
  0xFF3B82F6, // blue
  0xFFF59E0B, // amber
  0xFF10B981, // green
  0xFFEF4444, // red
  0xFFA855F7, // purple
  0xFF64748B, // slate
];

class DrawingController extends ChangeNotifier {
  final DrawingRepository _repository;
  final Logger _logger;

  /// symbol -> drawings
  final Map<String, List<Drawing>> _bySymbol = {};

  /// symbol -> undo/redo stack. Kept independently per symbol, so switching
  /// charts never mixes one symbol's history into another's, and a symbol's
  /// history survives switching away and back.
  final Map<String, DrawingHistory> _historyBySymbol = {};

  String _symbol;

  DrawingTool? _activeTool;
  AnalysisType? _activeAnalysisTool;
  Drawing? _pending;
  String? _selectedId;

  int _colorValue = kDrawingColors.first;
  double _strokeWidth = 1.5;

  /// Snapshot of the current symbol's drawing list taken at the start of a
  /// drag (move handle / move shape), so the whole gesture becomes one undo
  /// step rather than one per frame.
  List<Drawing>? _transientBefore;
  String? _transientSymbol;

  bool _isLoading = false;

  MagneticMode _magneticMode = MagneticMode.off;
  bool _continuousDrawingMode = false;

  late final HistoryManager _historyManager;

  DrawingController({
    required DrawingRepository repository,
    required Logger logger,
    required String symbol,
  })  : _repository = repository,
        _logger = logger,
        _symbol = symbol {
    _historyManager = HistoryManager(maxCapacity: 100);
  }

  HistoryManager get historyManager => _historyManager;

  // ==========================================================
  // STATE
  // ==========================================================

  String get symbol => _symbol;
  bool get isLoading => _isLoading;

  /// Completed drawings for the active symbol.
  List<Drawing> get drawings =>
      List.unmodifiable(_bySymbol[_symbol] ?? const <Drawing>[]);

  /// The shape currently being placed, if any.
  Drawing? get pending => _pending;

  DrawingTool? get activeTool => _activeTool;
  AnalysisType? get activeAnalysisTool => _activeAnalysisTool;
  bool get isDrawing => _activeTool != null || _activeAnalysisTool != null;
  String? get selectedId => _selectedId;
  int get colorValue => _colorValue;
  double get strokeWidth => _strokeWidth;
  bool get hasDrawings => drawings.isNotEmpty;
  MagneticMode get magneticMode => _magneticMode;
  bool get isContinuousDrawing => _continuousDrawingMode;

  void setContinuousDrawing(bool enabled) {
    if (_continuousDrawingMode == enabled) return;
    _continuousDrawingMode = enabled;
    notifyListeners();
  }

  void toggleContinuousDrawing() {
    _continuousDrawingMode = !_continuousDrawingMode;
    notifyListeners();
  }

  final Map<IndicatorType, IndicatorStyle> _indicatorStyles = {};

  IndicatorStyle indicatorStyleFor(IndicatorType type) {
    return _indicatorStyles[type] ?? IndicatorStyle.defaultStyle(type);
  }

  Map<IndicatorType, IndicatorStyle> get indicatorStyles =>
      Map.unmodifiable(_indicatorStyles);

  void setIndicatorStyle(IndicatorType type, IndicatorStyle style) {
    _indicatorStyles[type] = style;
    notifyListeners();
  }

  DrawingHistory get _history =>
      _historyBySymbol.putIfAbsent(_symbol, () => DrawingHistory());

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get undoDescription => _history.nextUndoDescription;
  String? get redoDescription => _history.nextRedoDescription;

  Drawing? get selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final d in drawings) {
      if (d.id == id) return d;
    }
    return null;
  }

  // ==========================================================
  // LOADING
  // ==========================================================

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final loaded = await _repository.getForSymbol(_symbol);
      _bySymbol[_symbol] = loaded;
    } catch (e) {
      _logger.warning('Drawing load failed for $_symbol: $e');
      _bySymbol[_symbol] ??= [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSymbol(String symbol) async {
    if (symbol == _symbol) return;
    cancelPending();
    _selectedId = null;
    _symbol = symbol;
    if (_bySymbol.containsKey(symbol)) {
      notifyListeners();
      return;
    }
    await load();
  }

  // ==========================================================
  // TOOL SELECTION
  // ==========================================================

  void setActiveTool(DrawingTool? tool) {
    if (_activeTool == tool && _activeAnalysisTool == null) {
      // Tapping the active tool again returns to pan/select mode.
      _activeTool = null;
    } else {
      _activeTool = tool;
      _activeAnalysisTool = null;
      _selectedId = null;
    }
    cancelPending();
    notifyListeners();
  }

  void setActiveAnalysisTool(AnalysisType? type) {
    if (_activeAnalysisTool == type) {
      _activeAnalysisTool = null;
      _activeTool = null;
    } else {
      _activeAnalysisTool = type;
      _activeTool = type?.underlyingTool;
      _selectedId = null;
    }
    cancelPending();
    notifyListeners();
  }

  void cycleMagneticMode() {
    _magneticMode = _magneticMode.next;
    notifyListeners();
  }

  void setMagneticMode(MagneticMode mode) {
    if (_magneticMode == mode) return;
    _magneticMode = mode;
    notifyListeners();
  }

  void setColor(int argb) {
    _colorValue = argb;
    final sel = selected;
    if (sel != null) {
      final before = _snapshot();
      _replace(sel.copyWith(colorValue: argb));
      _pushEdit(before, description: 'Change color');
      unawaited(_persist(sel.id));
    }
    notifyListeners();
  }

  void setStrokeWidth(double w) {
    _strokeWidth = w;
    final sel = selected;
    if (sel != null) {
      final before = _snapshot();
      _replace(sel.copyWith(strokeWidth: w));
      _pushEdit(before, description: 'Change thickness');
      unawaited(_persist(sel.id));
    }
    notifyListeners();
  }

  void updateDrawing(Drawing updated) {
    final before = _snapshot();
    _replace(updated);
    _pushEdit(before, description: 'Update ${updated.tool.label.toLowerCase()}');
    unawaited(_persist(updated.id));
    notifyListeners();
  }

  // ==========================================================
  // PLACEMENT
  // ==========================================================

  /// Add an anchor at the tapped data coordinate. Completes the shape once
  /// the tool's anchor count is satisfied.
  Future<void> addAnchor(DrawingAnchor anchor, {String? text}) async {
    final tool = _activeTool;
    final analysisType = _activeAnalysisTool;
    if (tool == null && analysisType == null) return;

    final current = _pending;

    if (current == null) {
      if (analysisType != null) {
        _pending = AnalysisToolFactory.createDrawing(
          type: analysisType,
          symbol: _symbol,
          anchors: [anchor],
          customLabel: text,
        ).copyWith(isComplete: false);
      } else if (tool != null) {
        _pending = Drawing(
          id: _newId(),
          tool: tool,
          symbol: _symbol,
          anchors: [anchor],
          colorValue: _colorValue,
          strokeWidth: _strokeWidth,
          text: text,
          isComplete: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
    } else {
      final existing = List<DrawingAnchor>.from(current.anchors);
      final reqAnchors = analysisType?.anchorCount ?? tool?.anchorCount ?? 2;
      if (existing.length < reqAnchors) {
        existing.add(anchor);
      } else {
        existing[reqAnchors - 1] = anchor;
      }
      _pending = current.copyWith(
        anchors: existing,
        text: text ?? current.text,
      );
    }

    final reqAnchors = analysisType?.anchorCount ?? tool?.anchorCount ?? 2;
    if (_pending!.anchors.length >= reqAnchors) {
      await _commitPending();
    } else {
      notifyListeners();
    }
  }

  Future<void> updateText(String id, String newText) async {
    final target = _find(id);
    if (target == null) return;
    final before = _snapshot();
    _replace(target.copyWith(text: newText));
    _pushEdit(before, description: 'Edit text');
    notifyListeners();
    await _persist(id);
  }

  /// Live preview while the second anchor is being dragged into place.
  void updatePendingLastAnchor(DrawingAnchor anchor) {
    final current = _pending;
    if (current == null || current.anchors.isEmpty) return;
    final anchors = List<DrawingAnchor>.from(current.anchors);
    if (anchors.length < current.tool.anchorCount) {
      anchors.add(anchor);
    } else {
      anchors[anchors.length - 1] = anchor;
    }
    _pending = current.copyWith(anchors: anchors);
    notifyListeners();
  }

  /// Commit whatever is currently pending.
  Future<void> commitPending() async {
    await _commitPending();
  }

  Future<void> _commitPending() async {
    final done = _pending;
    if (done == null) return;
    _pending = null;

    final before = _snapshot();
    final committed = done.copyWith(isComplete: true);
    _bySymbol.putIfAbsent(_symbol, () => []).add(committed);
    _pushEdit(before, description: 'Add ${committed.tool.label.toLowerCase()}');

    if (!_continuousDrawingMode) {
      _activeTool = null;
      _activeAnalysisTool = null;
    }
    _selectedId = committed.id;
    notifyListeners();

    try {
      await _repository.save(committed);
    } catch (e) {
      _logger.warning('Drawing save failed: $e');
    }
  }

  void cancelPending() {
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }

  // ==========================================================
  // SELECTION AND EDITING
  // ==========================================================

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Call once when a drag that will move a drawing begins (grabbing a handle
  /// or the shape body), so the whole gesture collapses into a single undo
  /// step instead of one per frame. Pairs with [commitEdit].
  void beginTransientEdit() {
    _transientBefore = _snapshot();
    _transientSymbol = _symbol;
  }

  /// Move one handle of the selected drawing. Call [commitEdit] when the
  /// gesture ends so the change is written once rather than per frame.
  void moveAnchor(String id, int handleIndex, DrawingAnchor to) {
    final target = _find(id);
    if (target == null) return;

    if (target.tool == DrawingTool.verticalLine && target.anchors.isNotEmpty) {
      _replace(target.withAnchorAt(0, target.anchors.first.copyWith(timestamp: to.timestamp)));
      notifyListeners();
      return;
    }

    if (target.tool == DrawingTool.rectangle && target.anchors.length >= 2) {
      if (handleIndex == 0) {
        _replace(target.withAnchorAt(0, to));
      } else if (handleIndex == 1) {
        _replace(target.withAnchorAt(1, to));
      } else if (handleIndex == 2) {
        // Corner 2 (Anchor 1 timestamp, Anchor 0 price)
        final a0 = target.anchors[0].copyWith(price: to.price);
        final a1 = target.anchors[1].copyWith(timestamp: to.timestamp);
        _replace(target.copyWith(anchors: [a0, a1]));
      } else if (handleIndex == 3) {
        // Corner 3 (Anchor 0 timestamp, Anchor 1 price)
        final a0 = target.anchors[0].copyWith(timestamp: to.timestamp);
        final a1 = target.anchors[1].copyWith(price: to.price);
        _replace(target.copyWith(anchors: [a0, a1]));
      }
      notifyListeners();
      return;
    }

    _replace(target.withAnchorAt(handleIndex, to));
    notifyListeners();
  }

  /// Drag the whole shape by a data-space delta.
  void translate(String id, int dtMs, double dPrice) {
    final target = _find(id);
    if (target == null) return;

    if (target.tool == DrawingTool.horizontalLine) {
      _replace(target.translated(0, dPrice));
    } else if (target.tool == DrawingTool.verticalLine) {
      _replace(target.translated(dtMs, 0));
    } else {
      _replace(target.translated(dtMs, dPrice));
    }
    notifyListeners();
  }

  /// Finalize a drag started with [beginTransientEdit]: pushes one history
  /// entry for the whole gesture and persists the result. Safe to call even
  /// without a matching [beginTransientEdit] (falls back to a plain persist),
  /// so existing call sites that only edit style, not position, keep working.
  Future<void> commitEdit(String id) async {
    final before = _transientBefore;
    final symbol = _transientSymbol;
    _transientBefore = null;
    _transientSymbol = null;

    if (before != null && symbol == _symbol) {
      _pushEdit(before, description: 'Move drawing');
    }
    await _persist(id);
  }

  // ==========================================================
  // DELETION
  // ==========================================================

  Future<void> deleteSelected() async {
    final id = _selectedId;
    if (id == null) return;
    await delete(id);
  }

  Future<void> delete(String id) async {
    final list = _bySymbol[_symbol];
    if (list == null) return;
    final index = list.indexWhere((d) => d.id == id);
    if (index < 0) return;

    final before = _snapshot();
    final removed = list.removeAt(index);
    if (_selectedId == id) _selectedId = null;
    _pushEdit(before, description: 'Delete ${removed.tool.label.toLowerCase()}');
    notifyListeners();

    try {
      await _repository.delete(id, _symbol);
    } catch (e) {
      _logger.warning('Drawing delete failed: $e');
    }
  }

  Future<void> clearSymbol() async {
    final list = _bySymbol[_symbol];
    if (list == null || list.isEmpty) return;

    final before = _snapshot();
    _bySymbol[_symbol] = [];
    _selectedId = null;
    _pushEdit(before, description: 'Clear all drawings');
    notifyListeners();

    try {
      await _repository.clearSymbol(_symbol);
    } catch (e) {
      _logger.warning('Drawing clear failed: $e');
    }
  }

  // ==========================================================
  // UNDO / REDO
  // ==========================================================

  Future<void> undo() async {
    final edit = _history.undo();
    if (edit == null) return;
    await _restore(edit.symbol, edit.before);
  }

  Future<void> redo() async {
    final edit = _history.redo();
    if (edit == null) return;
    await _restore(edit.symbol, edit.after);
  }

  Future<void> _restore(String symbol, List<Drawing> target) async {
    final current = _bySymbol[symbol] ?? const <Drawing>[];
    _bySymbol[symbol] = List<Drawing>.from(target);
    if (_selectedId != null &&
        !target.any((d) => d.id == _selectedId) &&
        symbol == _symbol) {
      _selectedId = null;
    }
    notifyListeners();
    await _reconcile(symbol, current, target);
  }

  // ==========================================================
  // INTERNAL
  // ==========================================================

  /// Shallow snapshot of the active symbol's drawing list. Cheap and safe:
  /// [Drawing] is immutable, so the copies never need deep-cloning — only the
  /// list itself needs to be a distinct instance so later in-place mutation
  /// doesn't retroactively change the snapshot.
  List<Drawing> _snapshot() => List<Drawing>.from(_bySymbol[_symbol] ?? const []);

  void _pushEdit(List<Drawing> before, {required String description}) {
    _history.push(DrawingEdit(
      symbol: _symbol,
      before: before,
      after: _snapshot(),
      description: description,
    ));
  }

  /// Reconciles the repository with a jump from [from] to [to] (used by
  /// undo/redo, which replace the whole list rather than applying one
  /// mutation): deletes anything dropped, upserts everything present.
  /// `save` is an insert-or-replace, so re-saving unchanged drawings is
  /// harmless — cheaper than diffing content for sets this small.
  Future<void> _reconcile(
    String symbol,
    List<Drawing> from,
    List<Drawing> to,
  ) async {
    final toIds = to.map((d) => d.id).toSet();
    for (final d in from) {
      if (toIds.contains(d.id)) continue;
      try {
        await _repository.delete(d.id, symbol);
      } catch (e) {
        _logger.warning('Drawing history delete failed: $e');
      }
    }
    for (final d in to) {
      try {
        await _repository.save(d);
      } catch (e) {
        _logger.warning('Drawing history save failed: $e');
      }
    }
  }

  Drawing? _find(String id) {
    for (final d in _bySymbol[_symbol] ?? const <Drawing>[]) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _replace(Drawing updated) {
    final list = _bySymbol[_symbol];
    if (list == null) return;
    final index = list.indexWhere((d) => d.id == updated.id);
    if (index >= 0) list[index] = updated;
  }

  Future<void> _persist(String id) async {
    final target = _find(id);
    if (target == null) return;
    try {
      await _repository.save(target);
    } catch (e) {
      _logger.warning('Drawing persist failed: $e');
    }
  }

  int _seq = 0;
  String _newId() =>
      'd${DateTime.now().millisecondsSinceEpoch}_${_seq++}';
}
