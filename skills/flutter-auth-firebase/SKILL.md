---
name: flutter-auth-firebase
description: Implements Firebase auth in Flutter with Google Sign-In, Apple Sign-In (with the correct token + nonce + authorizationCode sequence), and email/password. Trigger this skill whenever the user mentions Firebase auth, signInWithCredential, OAuthProvider, sign in with Apple, sign in with Google, invalid-credential error, "Passed nonce and nonce in id_token should either both exist or not", or any auth flow in a Flutter project that has firebase_auth in pubspec. This skill prevents the most common Apple Sign-In bugs: missing authorizationCode, swapped raw/hashed nonce, lost displayName on second login, and skipped SHA-1 fingerprints. Use this BEFORE writing any auth code in a Firebase Flutter project.
---

# Flutter Firebase Auth (with Apple Sign-In done right)

The #1 reason Firebase Sign in with Apple breaks in Flutter is a nonce/token sequencing mistake. This skill exists to make that impossible.

## Required Packages (latest stable, check pub.dev before pinning)

```yaml
dependencies:
  firebase_core: ^latest
  firebase_auth: ^latest
  google_sign_in: ^latest
  sign_in_with_apple: ^latest
  crypto: ^latest
```

`crypto` is mandatory, do not skip it. The 12 KB it adds is the cheapest auth-security trade in the project.

## Critical: Apple Sign-In Nonce Sequence

This is where 90% of Flutter devs get stuck. The sequence is:

1. Generate a `rawNonce` (random string from `Random.secure()`)
2. Hash it with SHA-256, get `hashedNonce`
3. Send **hashed** nonce to Apple in `getAppleIDCredential(nonce: hashedNonce)`
4. Apple returns `identityToken` (which embeds the hashed nonce)
5. Send the **raw** nonce to Firebase in `OAuthProvider("apple.com").credential(rawNonce: rawNonce)`
6. Firebase re-hashes the raw nonce and matches it against the token

**Apple gets hashed. Firebase gets raw.** If swapped, you get "invalid-credential" or "Passed nonce and nonce in id_token should either both exist or not".

## Reference Implementation: Apple Sign-In

```dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthService {
  /// Generates a cryptographically secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA-256 hash of a string.
  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<UserCredential> signInWithApple() async {
    // 1. Generate raw nonce
    final rawNonce = _generateNonce();
    // 2. Hash it for Apple
    final hashedNonce = _sha256(rawNonce);

    // 3. Request credential from Apple using HASHED nonce
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    // 4. Build Firebase credential using RAW nonce
    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      // CRITICAL: authorizationCode is required by Firebase as accessToken.
      // Skipping this is the #1 cause of "invalid-credential" errors.
      accessToken: appleCredential.authorizationCode,
    );

    // 5. Sign in to Firebase
    final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    // 6. CRITICAL: Apple only sends full name on FIRST sign-in.
    // Capture and persist immediately, or it is lost forever.
    if (userCredential.additionalUserInfo?.isNewUser ?? false) {
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final displayName = [givenName, familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (displayName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
        // ALSO save to your backend (Firestore, Supabase, etc.) here.
        // Apple will never send this name again on subsequent logins.
      }
    }

    return userCredential;
  }
}
```

### Apple Sign-In Common Pitfalls (Pre-flight Check)

Before debugging an Apple Sign-In failure, verify all of these:

- [ ] `accessToken: appleCredential.authorizationCode` is present in OAuthProvider
- [ ] `rawNonce` is passed to Firebase, `hashedNonce` to Apple, never swapped
- [ ] `Sign in with Apple` capability is enabled in Xcode Signing & Capabilities
- [ ] `Sign in with Apple` is enabled in Firebase Console (Authentication > Sign-in method)
- [ ] Bundle ID matches between Xcode, Apple Developer, and Firebase
- [ ] Apple Developer account has a Services ID configured (for web/Android only, iOS native does not need it)
- [ ] Testing on a real device (Apple Sign-In does NOT work on iOS Simulator)
- [ ] Privacy policy URL is set in App Store Connect (Apple rejects apps with auth but no privacy policy)

## Reference Implementation: Google Sign-In

Always pass BOTH `idToken` and `accessToken` to Firebase. Missing accessToken is the most common Google Sign-In bug.

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final googleAuth = await googleUser.authentication;

    // BOTH tokens are required by Firebase, do not omit accessToken
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    // Always sign out from BOTH services
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }
}
```

### Google Sign-In Common Pitfalls

- [ ] SHA-1 fingerprint added to Firebase for BOTH debug AND release variants (release builds break if missing)
- [ ] `google-services.json` updated after adding SHA-1
- [ ] `GoogleService-Info.plist` in iOS project, target membership set
- [ ] iOS URL Scheme configured (REVERSED_CLIENT_ID from GoogleService-Info.plist) in Info.plist
- [ ] Both `idToken` AND `accessToken` passed to GoogleAuthProvider.credential()

## Apple App Store Submission Implications

If the app offers Google or Facebook sign-in, Apple's App Review guideline 4.8 REQUIRES offering Sign in with Apple too. Apps that ship Google-only or Facebook-only auth get rejected. The rule does NOT apply if the app only offers email/password.

This means: if `google_sign_in` is in pubspec, `sign_in_with_apple` must also be in pubspec.

## Auth State Management with Riverpod

In Riverpod 3.x codegen projects, expose Firebase auth state as a provider:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@riverpod
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  return FirebaseAuth.instance.authStateChanges();
}

@riverpod
class AuthController extends _$AuthController {
  @override
  AsyncValue<User?> build() {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    return AsyncValue.data(user);
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await AppleAuthService().signInWithApple();
      return cred.user;
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await FirebaseAuth.instance.signOut();
      return null;
    });
  }
}
```

After writing this, always run: `dart run build_runner build --delete-conflicting-outputs`

## File Organization

In a feature-first project:

```
lib/
├── features/
│   └── auth/
│       ├── data/
│       │   └── auth_repository.dart        (FirebaseAuth wrapper)
│       ├── domain/
│       │   └── app_user.dart                (Freezed model)
│       └── presentation/
│           ├── providers/
│           │   └── auth_providers.dart      (Riverpod providers above)
│           ├── widgets/
│           │   ├── apple_sign_in_button.dart
│           │   └── google_sign_in_button.dart
│           └── screens/
│               └── login_screen.dart
```

Auth logic NEVER goes inside widgets. Widgets call providers, providers call repositories, repositories call FirebaseAuth.

## When Things Break: Diagnostic Order

1. **"invalid-credential"** → 99% of the time, missing `accessToken: appleCredential.authorizationCode` in OAuthProvider
2. **"Nonces mismatch"** → Raw/hashed swapped, Apple gets hashed, Firebase gets raw
3. **"PlatformException(sign_in_canceled)"** → User cancelled, this is normal, just handle it
4. **Google sign-in works in debug, fails in release** → SHA-1 release fingerprint missing in Firebase
5. **Apple sign-in popup never appears** → Capability not added in Xcode, or running on Simulator
6. **Display name disappears on second login** → Did not save it on first login when `isNewUser == true`

## Do NOT

- Do NOT use `signInWithPopup` or `signInWithRedirect` (those are web-only)
- Do NOT skip the `crypto` package, do not implement SHA-256 manually
- Do NOT store nonce in shared state, generate fresh per sign-in attempt
- Do NOT call `getAppleIDCredential` without a nonce (Firebase will reject the resulting token)
- Do NOT assume Apple will send the user's name on every login (only the first)
- Do NOT test Apple Sign-In on iOS Simulator, it does not work, use a real device
## Auth Error Handling

Auth exceptions (`invalid-credential`, `network-request-failed`, `too-many-requests`, `user-disabled`) must be caught in the repository layer and mapped to domain `Failure` types before surfacing to the UI. Do not pass raw `FirebaseAuthException` messages to users.

Consult `flutter-error-handling` for:
- The `Failure` sealed class definition
- How to map exceptions in the repository
- How to display auth errors via `AsyncValue.when()` in Riverpod providers
- When to use SnackBar vs inline error vs full-screen error for auth failures