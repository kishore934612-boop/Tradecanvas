import 'package:app/models/trading_models.dart';

abstract class TradeRepository {
  Future<List<Trade>> getTrades(String userId);
  Future<void> addTrade(String userId, Trade trade);
  Future<void> updateTradeJournal(String userId, String tradeId, ExitJournal journal);
  Future<void> updateTradeNotes(String userId, String tradeId, String notes);
  Future<void> clearTrades(String userId);
}
