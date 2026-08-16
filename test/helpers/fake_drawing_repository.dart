/// In-memory [DrawingRepository] fake for testing [DrawingController].
library;

import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/models/drawing.dart';

class FakeDrawingRepository implements DrawingRepository {
  final Map<String, Drawing> _byId = {};

  /// Direct view for assertions, independent of the controller under test.
  List<Drawing> get all => _byId.values.toList();

  @override
  Future<List<Drawing>> getForSymbol(String symbol) async {
    return _byId.values.where((d) => d.symbol == symbol).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<String>> symbolsWithDrawings() async {
    return _byId.values.map((d) => d.symbol).toSet().toList();
  }

  @override
  Future<void> save(Drawing drawing) async {
    _byId[drawing.id] = drawing;
  }

  @override
  Future<void> delete(String id, String symbol) async {
    _byId.remove(id);
  }

  @override
  Future<void> clearSymbol(String symbol) async {
    _byId.removeWhere((_, d) => d.symbol == symbol);
  }
}
