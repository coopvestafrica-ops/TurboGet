// Smoke tests for the TurboGet app.
//
// These tests exercise the building blocks that do not require a real
// Android host: the user model's password hashing and the first-run
// setup screen (reached when no super-admin exists). Anything that
// depends on MethodChannel plugins (downloads, AdMob, DB) is out of
// scope for widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turboget/models/user.dart';
import 'package:turboget/screens/first_run_setup_screen.dart';

void main() {
  group('User.hashPassword', () {
    test('produces the same hash for the same salt + password', () {
      final a = User.hashPassword('hunter2', 'abc');
      final b = User.hashPassword('hunter2', 'abc');
      expect(a, equals(b));
    });

    test('differs across salts', () {
      final a = User.hashPassword('hunter2', 'abc');
      final b = User.hashPassword('hunter2', 'xyz');
      expect(a, isNot(equals(b)));
    });
  });

  group('User.verifyPassword', () {
    test('accepts the correct password', () {
      const salt = 'salt-123';
      final u = User(
        id: 'u1',
        username: 'admin',
        passwordHash: User.hashPassword('correct horse', salt),
        passwordSalt: salt,
        role: UserRole.superAdmin,
        createdAt: DateTime.now(),
      );
      expect(u.verifyPassword('correct horse'), isTrue);
      expect(u.verifyPassword('wrong'), isFalse);
    });
  });

  testWidgets('First-run setup screen renders and validates input',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FirstRunSetupScreen()),
    );

    expect(find.text('Create the admin account'), findsOneWidget);
    expect(find.text('Create admin account'), findsOneWidget);

    // Tapping submit with empty fields should surface validation errors.
    await tester.tap(find.text('Create admin account'));
    await tester.pump();
    expect(find.text('Username is required'), findsOneWidget);
  });
}
