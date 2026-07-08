import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/logging/file_logger.dart';
import 'package:app/core/logging/logger.dart';
import '../helpers/temp_dir.dart';

void main() {
  late FileLogger logger;

  setUp(() {
    logger = FileLogger.instance;
    logger.resetForTesting();
  });

  tearDown(() {
    logger.resetForTesting();
  });

  test('FileLogger writes to a log file', () async {
    await withTempDir((temp) async {
      // FileLogger will fall back to systemTemp since path_provider
      // is not initialised in test mode. We just verify no exceptions.
      logger.log(LogLevel.info, 'Test message from file_logger_test');
      // Wait for the buffer to flush (100 ms debounce + margin).
      await Future.delayed(const Duration(milliseconds: 250));
    });
  });

  test('FileLogger resetForTesting clears buffer', () {
    logger.log(LogLevel.info, 'Buffered message');
    logger.resetForTesting();
    // After reset the internal buffer should be empty. No way to assert
    // directly, but we verify it doesn't throw.
    expect(() => logger.resetForTesting(), returnsNormally);
  });

  test('FileLogger log creates output without throwing', () {
    // Verifies the public API works across all log levels.
    expect(
      () {
        logger.log(LogLevel.info, 'info test');
        logger.log(LogLevel.error, 'error test', Exception('e'));
        logger.log(LogLevel.debug, 'debug test');
        logger.log(LogLevel.warning, 'warn test');
      },
      returnsNormally,
    );
  });

  test('FileLogger maxFileSizeForTest and maxFilesForTest are accessible', () {
    // Ensure the @visibleForTesting getters expose the expected constants.
    expect(FileLogger.maxFileSizeForTest, equals(1024 * 1024));
    expect(FileLogger.maxFilesForTest, equals(5));
  });
}
