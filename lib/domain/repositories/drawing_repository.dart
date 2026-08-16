/// Drawing repository interface.
///
/// Drawings are per-symbol and per-user. Implementations are responsible for
/// scoping reads and writes to the current user id.
library;

import 'package:app/models/drawing.dart';

abstract class DrawingRepository {
  /// All drawings for one symbol, oldest first.
  Future<List<Drawing>> getForSymbol(String symbol);

  /// Symbols that currently have at least one drawing.
  Future<List<String>> symbolsWithDrawings();

  /// Insert or update a drawing.
  Future<void> save(Drawing drawing);

  /// Delete one drawing by id.
  Future<void> delete(String id, String symbol);

  /// Delete every drawing for a symbol.
  Future<void> clearSymbol(String symbol);
}
