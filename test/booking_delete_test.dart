import 'package:flutter_test/flutter_test.dart';

/// Mirrors BookingNotifier.removeBooking's error handling.
///
/// The bug: the catch block swallowed the exception, so the manage screen's
/// try/catch never fired and it told the user "Booking deleted successfully"
/// while the record was still there.
class _FakeNotifier {
  List<String> state;
  final bool serverFails;
  _FakeNotifier(this.state, {this.serverFails = false});

  Future<void> removeBooking(String id) async {
    final previous = List<String>.from(state);
    state = state.where((b) => b != id).toList(); // optimistic
    try {
      if (serverFails) throw Exception('Server said no');
    } catch (_) {
      state = previous; // rollback
      rethrow; // <-- the fix
    }
  }
}

void main() {
  test('successful delete removes the booking', () async {
    final n = _FakeNotifier(['a', 'b']);
    await n.removeBooking('a');
    expect(n.state, ['b']);
  });

  test('failed delete rethrows so the caller can report it', () async {
    final n = _FakeNotifier(['a', 'b'], serverFails: true);
    await expectLater(n.removeBooking('a'), throwsA(isA<Exception>()));
  });

  test('failed delete rolls the list back instead of losing the booking',
      () async {
    final n = _FakeNotifier(['a', 'b'], serverFails: true);
    try {
      await n.removeBooking('a');
    } catch (_) {
      // expected
    }
    // The booking must reappear, not vanish from the UI.
    expect(n.state, ['a', 'b']);
  });

  test('caller sees failure — the old swallow reported false success',
      () async {
    final n = _FakeNotifier(['a'], serverFails: true);
    var reportedSuccess = false;
    try {
      await n.removeBooking('a');
      reportedSuccess = true; // what the screen used to do
    } catch (_) {
      reportedSuccess = false;
    }
    expect(reportedSuccess, isFalse,
        reason: 'a failed delete must never report success');
  });
}
