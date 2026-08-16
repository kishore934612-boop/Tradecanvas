/// Session — resolves the id that local rows are scoped to.
///
/// Local database rows are saved under [kGuestUserId].
library;

/// Row owner id used for local database storage.
const String kGuestUserId = 'guest';

abstract class SessionProvider {
  /// Current owner id — [kGuestUserId].
  String get userId;

  bool get isAuthenticated;
}

class LocalSession implements SessionProvider {
  const LocalSession();

  @override
  String get userId => kGuestUserId;

  @override
  bool get isAuthenticated => false;
}

/// Fixed-id session for tests.
class StaticSession implements SessionProvider {
  final String id;
  final bool authenticated;

  const StaticSession(this.id, {this.authenticated = false});

  @override
  String get userId => id;

  @override
  bool get isAuthenticated => authenticated;
}
