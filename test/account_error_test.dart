import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/services/app_error.dart';

void main() {
  test(
    'Missing deployment produces an actionable message instead of Exception',
    () {
      expect(
        accountServiceMessage(404, {
          'code': 'NOT_FOUND',
          'message': 'Requested function was not found',
        }),
        contains('not deployed'),
      );
    },
  );
  test('Server error and message envelopes both preserve useful feedback', () {
    expect(
      accountServiceMessage(400, {'error': 'Email already registered'}),
      'Email already registered',
    );
    expect(
      accountServiceMessage(400, {'message': 'Invalid email'}),
      'Invalid email',
    );
    expect(
      accountServiceMessage(400, {
        'error': {'message': 'Invalid name'},
      }),
      'Invalid name',
    );
    expect(
      accountServiceMessage(500, {'code': 'FAILED'}),
      'The account could not be saved. Please try again.',
    );
  });
}
