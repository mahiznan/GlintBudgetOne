import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/auth/auth_state.dart';

void main() {
  group('AuthState', () {
    test('AuthLoading is an AuthState', () {
      const state = AuthLoading();
      expect(state, isA<AuthState>());
    });

    test('AuthUnauthenticated is an AuthState', () {
      const state = AuthUnauthenticated();
      expect(state, isA<AuthState>());
    });

    test('AuthAuthenticated holds user data', () {
      const user = AuthUser(uid: 'uid-123', email: 'test@example.com');
      const state = AuthAuthenticated(user: user);
      expect(state.user.uid, 'uid-123');
      expect(state.user.email, 'test@example.com');
      expect(state.user.displayName, isNull);
    });

    test('AuthUser exposes all fields', () {
      const user = AuthUser(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        photoUrl: 'https://example.com/photo.jpg',
      );
      expect(user.displayName, 'Alice');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
    });
  });
}
