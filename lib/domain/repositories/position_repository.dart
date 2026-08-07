import 'package:app/models/trading_models.dart';

abstract class PositionRepository {
  Future<List<Position>> getPositions(String userId);
  Future<void> addPosition(String userId, Position position);
  Future<void> updatePosition(String userId, Position position);
  Future<void> removePosition(String userId, String positionId);
  Future<void> clearPositions(String userId);
}
