import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/logging/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLogger loggerInstance;

  setUp(() {
    loggerInstance = AppLogger.instance;
    loggerInstance.setEnabled(true);
    loggerInstance.setMinLevel(LogLevel.debug);
  });

  group('AppLogger', () {
    test('Logger can be enabled and disabled', () {
      loggerInstance.setEnabled(false);
      loggerInstance.info('This shouldn\'t print');
      loggerInstance.setEnabled(true);
      loggerInstance.info('This can print');
    });

    test('setMinLevel filters below-threshold messages', () {
      loggerInstance.setMinLevel(LogLevel.warning);
      loggerInstance.debug('Debug message (ignored)');
      loggerInstance.info('Info message (ignored)');
      loggerInstance.warning('Warning message (logged)');
    });

    test('All log methods exist and do not throw', () {
      expect(() => loggerInstance.debug('debug log'), returnsNormally);
      expect(() => loggerInstance.info('info log'), returnsNormally);
      expect(() => loggerInstance.warning('warning log'), returnsNormally);
      expect(() => loggerInstance.error('error log', Exception('test')), returnsNormally);
      expect(() => loggerInstance.network('network log'), returnsNormally);
      expect(() => loggerInstance.market('market log'), returnsNormally);
      expect(() => loggerInstance.trade('trade log'), returnsNormally);
      expect(() => loggerInstance.chart('chart log'), returnsNormally);
    });
  });
}
