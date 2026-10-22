import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_client.dart';
import 'models/auth_user.dart' show AuthSession;
import 'services/auth_service.dart' as api_auth;

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    await credential.user?.sendEmailVerification();
    await credential.user?.reload();
    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'تم إلغاء تسجيل الدخول بواسطة Google.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    // Google sign-in normally verifies the email, but check the actual user state.
    await result.user?.reload();
    return result;
  }

  /// Signs in with Google and exchanges the Google ID token with the platform API.
  /// The backend independently verifies the token before issuing its own session.
  Future<AuthSession> signInWithGoogleForPlatform(
    api_auth.AuthService apiService,
  ) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'تم إلغاء تسجيل الدخول بواسطة Google.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'google-id-token-missing',
        message: 'لم يتم استلام رمز التحقق من Google. تحقق من إعداد OAuth.',
      );
    }

    final firebaseCredential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
    );

    try {
      await _auth.signInWithCredential(firebaseCredential);
      final session = await apiService.signInWithGoogle(idToken: idToken);
      return session;
    } catch (_) {
      // Avoid leaving a Firebase-only session when platform API login fails.
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('لا يوجد حساب مسجل حاليًا.');
    await user.sendEmailVerification();
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Firebase sign-out must still happen if Google local sign-out fails.
    }
    await _auth.signOut();
  }
}
