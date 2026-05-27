---
name: flutter-auth-supabase
description: Implements Supabase auth in Flutter with Google Sign-In, Apple Sign-In (with the correct rawNonce + hashedNonce + authorizationCode sequence), email/password, and magic links. Trigger this skill whenever the user mentions Supabase auth, signInWithIdToken, signInWithOAuth, Supabase sign in with Apple, "Nonces mismatch", or any auth flow in a Flutter project that has supabase_flutter in pubspec. Prevents the most common Apple Sign-In bugs with Supabase: missing hashed/raw nonce flow, idToken validation failure, and Services ID misconfiguration. Use this BEFORE writing any auth code in a Supabase Flutter project.
---

# Flutter Supabase Auth (with Apple Sign-In done right)

The Supabase equivalent of `flutter-auth-firebase`. Same nonce nightmare, different SDK.

## Required Packages

```yaml
dependencies:
  supabase_flutter: ^latest
  google_sign_in: ^latest
  sign_in_with_apple: ^latest
  crypto: ^latest
```

## Initialization

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

## Apple Sign-In: The Right Way

Apple gets the HASHED nonce. Supabase gets the RAW nonce. Same rule as Firebase.

```dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAppleAuthService {
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<AuthResponse> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw Exception('Apple sign-in: no idToken returned');
    }

    // Supabase gets the RAW nonce
    final response = await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Capture user's display name on FIRST sign-in only
    if (response.user != null && credential.givenName != null) {
      final fullName = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (fullName.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      }
    }

    return response;
  }
}
```

### Why Services ID is NOT needed for iOS-native

If the app is iOS-native and you use `getAppleIDCredential` (not OAuth redirect), Supabase validates the idToken directly against Apple's public keys. You do NOT need:
- Services ID
- .p8 key
- Apple OAuth redirect URL

These are only required for Android/web OAuth flow.

### Configuring Supabase for Apple

In Supabase dashboard → Authentication → Providers → Apple:
- [ ] Enable Apple provider
- [ ] Add your iOS app's Bundle ID to "Client IDs (for OAuth flow, comma separated)"
  - This is the ONLY field needed for native iOS flow
- [ ] For Android/web: also configure Services ID, Team ID, Key ID, .p8 key

## Google Sign-In with Supabase

iOS-native flow with `google_sign_in`:

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseGoogleAuthService {
  final _googleSignIn = GoogleSignIn(
    // iOS: clientId from GoogleService-Info.plist if used,
    // Android: leave empty (auto-detected)
    serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
  );

  Future<AuthResponse?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('Google sign-in: no idToken returned');
    }

    return Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }
}
```

For Google with Supabase, you need a Web OAuth client ID configured in Google Cloud Console, even for native flow. Add it as `serverClientId` in `GoogleSignIn()`.

In Supabase dashboard → Authentication → Providers → Google:
- [ ] Enable Google provider
- [ ] Add Web OAuth Client ID + Secret

## Email/Password and Magic Links

```dart
// Sign up
final res = await supabase.auth.signUp(
  email: 'user@example.com',
  password: 'Pass123!',
);

// Sign in
final res = await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'Pass123!',
);

// Magic link
await supabase.auth.signInWithOtp(
  email: 'user@example.com',
  emailRedirectTo: 'io.yourapp://login-callback',
);

// Deep link handling for magic link click
// Set up in iOS Info.plist and Android AndroidManifest.xml
// Use uni_links or app_links package to receive the callback
```

## Riverpod Integration

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_auth_providers.g.dart';

@riverpod
Stream<AuthState> authStateChanges(AuthStateChangesRef ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}

@riverpod
User? currentUser(CurrentUserRef ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.session?.user;
}
```

## Diagnostic Order

1. **"Nonces mismatch"** → raw/hashed swapped, Apple gets hashed, Supabase gets raw
2. **"Invalid login credentials"** → email or password wrong, OR email not confirmed if confirmation is required
3. **Google sign-in works in debug, fails in release** → SHA-1 release fingerprint missing in Google Cloud Console
4. **Apple sign-in returns null user** → Bundle ID mismatch in Supabase Apple provider config
5. **Magic link doesn't open app** → deep link not configured in iOS Info.plist URL Types or Android intent-filter

## Apple Submission Reminder

If `google_sign_in` is in pubspec, `sign_in_with_apple` MUST also be in pubspec. Apple Guideline 4.8 requires it. Without it, app gets rejected. See `flutter-store-review-checker`.

## Strict Rules

- DO NOT swap raw and hashed nonce (Apple = hashed, Supabase = raw)
- DO NOT skip `crypto` package, do not implement SHA-256 manually
- DO NOT call Supabase methods before `Supabase.initialize()` completes
- DO NOT store Supabase keys in client without RLS policies on the backend
- DO NOT skip RLS (Row Level Security) policies on Supabase tables, the anon key gives anyone read access otherwise

## Auth Error Handling

Supabase auth exceptions (`AuthException`, network failures, nonce mismatches) must be caught in the repository layer and mapped to domain `Failure` types before surfacing to the UI. Do not pass raw `AuthException.message` strings to users — they contain technical details.

Consult `flutter-error-handling` for:
- The `Failure` sealed class definition
- How to map exceptions in the repository
- How to display auth errors via `AsyncValue.when()` in Riverpod providers
- When to use SnackBar vs inline error vs full-screen error for auth failures
- DO NOT trust `auth.currentUser` synchronously, always wait for `onAuthStateChange` or use `getUser()` async call
