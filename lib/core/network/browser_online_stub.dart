// Non-web: no browser online/offline events. Connectivity is inferred purely
// from request outcomes.

bool isOnline() => true;

Stream<bool> onlineChanges() => const Stream.empty();
