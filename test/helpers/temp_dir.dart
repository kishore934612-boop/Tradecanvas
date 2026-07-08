import 'dart:io';

/// Utility to run a test body with a temporary directory.
///
/// Creates a temporary directory, passes it to [body], and deletes
/// the directory after the body completes (regardless of success/failure).
Future<void> withTempDir(Future<void> Function(Directory tempDir) body) async {
  final temp = await Directory.systemTemp.createTemp('tradeverse_test_');
  try {
    await body(temp);
  } finally {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  }
}
