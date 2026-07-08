// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:app/core/logging/file_logger.dart';
import 'package:app/core/logging/logger.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

class LoggingBenchmark extends BenchmarkBase {
  LoggingBenchmark() : super('FileLogger');

  @override
  void run() {
    FileLogger.instance.log(LogLevel.info, 'Benchmark message');
  }
}

void main() async {
  // Ensure logger is reset.
  final logger = FileLogger.instance;
  logger.resetForTesting();
  // Warm up.
  logger.log(LogLevel.info, 'Warmup');
  await Future.delayed(const Duration(milliseconds: 100));
  // Run benchmark.
  LoggingBenchmark().report();
  // Clean up.
  logger.resetForTesting();
}
