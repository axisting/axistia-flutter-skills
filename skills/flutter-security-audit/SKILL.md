---
name: flutter-security-audit
description: Audits Flutter mobile apps against OWASP Mobile Top 10 (2024) vulnerabilities. Trigger this skill before any production release, when the user mentions "security audit", "OWASP", "penetration test", "App Store rejection security", "hardcoded API key", "secrets in code", or any concern about leaked credentials, insecure storage, or weak crypto. Combines automated scanning (grep for hardcoded secrets, dependency CVE check, network security analysis) with manual checklist (storage, crypto, IPC, runtime protections). NOT a replacement for professional pentesting on apps handling financial/health data, but catches 90% of common issues.
---

# Flutter Security Audit (OWASP Mobile Top 10 2024)

This skill runs an automated + manual security audit on a Flutter project. Catches the common stuff before release.

## OWASP Mobile Top 10 (2024) Categories Covered

| Category | What it covers |
|----------|----------------|
| M1: Improper Credential Usage | Hardcoded API keys, secrets in source |
| M2: Inadequate Supply Chain Security | Outdated/vulnerable packages |
| M3: Insecure Authentication/Authorization | Weak auth flows, missing token expiry |
| M4: Insufficient Input/Output Validation | SQL injection, XSS in webviews |
| M5: Insecure Communication | HTTP instead of HTTPS, weak TLS |
| M6: Inadequate Privacy Controls | PII leaks, excessive permissions |
| M7: Insufficient Binary Protections | Missing obfuscation, debuggable releases |
| M8: Security Misconfiguration | Exported components, debug flags |
| M9: Insecure Data Storage | Plaintext tokens, SharedPreferences for secrets |
| M10: Insufficient Cryptography | MD5, weak random, hardcoded IVs |

## Step 1: Automated Scans

Run these scripts in order. They live in `scripts/` next to this SKILL.md.

### 1a: Hardcoded secrets

```bash
./scripts/scan-hardcoded-secrets.sh <project-root>
```

Looks for:
- API keys (Google, Firebase, AWS, Stripe, RevenueCat, Supabase patterns)
- JWT tokens hardcoded in source
- OAuth client secrets
- High-entropy strings that look like keys
- `.env` files committed to git

Common findings:
- `firebase_options.dart` is FINE (auto-generated, contains public anon-style API key)
- A standalone `secrets.dart` with values is NOT FINE
- Anything matching `AKIA[0-9A-Z]{16}` is an AWS key, BLOCKER
- Anything matching `sk_live_[a-zA-Z0-9]+` is a Stripe LIVE key, CRITICAL BLOCKER

### 1b: Dependency vulnerabilities

```bash
flutter pub outdated --show-all
dart pub deps -s compact
```

Check each direct dependency on pub.dev for:
- Latest version
- Pub Points score (under 100 is a yellow flag)
- Last published date (over 1 year old without updates is a yellow flag, unless it's a stable utility)
- Verified publisher badge

Report packages that are abandoned, deprecated, or have known CVEs.

### 1c: Network security

```bash
./scripts/scan-network-security.sh <project-root>
```

Looks for:
- `http://` URLs in Dart code (should be `https://`)
- iOS `NSAppTransportSecurity` exceptions in Info.plist (NSAllowsArbitraryLoads = true is a BLOCKER)
- Android `usesCleartextTraffic="true"` in AndroidManifest.xml (BLOCKER)
- Missing `network_security_config.xml` on Android
- Certificate pinning configured? (for financial/health apps, this should be present)

### 1d: Storage security

```bash
./scripts/scan-storage-security.sh <project-root>
```

Looks for:
- `SharedPreferences` being used for sensitive data (tokens, passwords, PII)
- Anything that should be in `flutter_secure_storage` is in plain storage
- Unencrypted Hive boxes containing sensitive data
- Files written to external storage with sensitive content (Android)

## Step 2: Manual Checklist

After running the scans, the model should manually inspect for these (scans can't catch them):

### Authentication & Authorization
- [ ] Tokens have expiry (refresh tokens, JWT exp claim)
- [ ] Tokens are revocable from the server (logout invalidates remotely)
- [ ] No "stay logged in forever" without re-auth on sensitive operations
- [ ] Password reset flow uses email/SMS verification, not security questions
- [ ] Biometric auth (if used) uses `local_auth` properly, with fallback to passcode

### Crypto
- [ ] No MD5, no SHA-1 for security purposes (SHA-256 minimum)
- [ ] Use `Random.secure()`, never plain `Random()` for tokens/nonces/keys
- [ ] No hardcoded IVs in AES encryption, use `crypto` package or `cryptography` package
- [ ] TLS version pinned to 1.2 or above

### Privacy / PII
- [ ] No PII (email, name, location) logged to console or files
- [ ] Sentry/Crashlytics scrubs PII before sending
- [ ] App handles GDPR delete-my-data requests
- [ ] Location permission only requested when actually used, not at app start
- [ ] Camera/microphone permissions only when feature is opened

### Binary Protections
- [ ] Release builds have `--obfuscate` flag (`flutter build apk --obfuscate --split-debug-info=build/symbols`)
- [ ] Release builds are NOT debuggable (`android:debuggable="false"` in release manifest)
- [ ] ProGuard / R8 enabled on Android release
- [ ] iOS release builds use `Release` configuration, not `Debug`

### Configuration
- [ ] `firebase_options.dart` does not contain server secrets (only public config, which is fine)
- [ ] No `.env` file with prod credentials committed (use `--dart-define` instead)
- [ ] Different Firebase projects for dev / staging / prod (otherwise dev test data pollutes prod)
- [ ] Android `exported` flag is explicitly set on every activity and receiver (true or false), no implicit defaults
- [ ] Deep link URL schemes do not expose internal app state via parameters

### Code Quality (Security-Adjacent)
- [ ] `flutter analyze` returns zero issues
- [ ] No `// ignore_for_file: ...` covering security-sensitive code without justification
- [ ] No `try { ... } catch (_) {}` swallowing security errors silently
- [ ] No string concatenation building SQL/SQLite queries, use parameterized queries

### Webview (if used)
- [ ] `javaScriptMode` explicitly set, not default-enabled if not needed
- [ ] No `loadUrl` of user-supplied URLs without validation
- [ ] Webview can't load arbitrary `file://` URLs
- [ ] `webview_flutter` is the package (NOT `flutter_webview_plugin`, which is abandoned)

### Backend Trust Boundary
- [ ] App does NOT trust client-side validation for security decisions (always server-side)
- [ ] App does NOT contain admin-only functionality gated only by a UI hide flag
- [ ] Supabase apps: Row Level Security (RLS) policies enabled on ALL tables exposed via anon key
- [ ] Firebase apps: Firestore rules deny by default, only allow specific patterns

## Step 3: Report

Output a structured report:

```
SECURITY AUDIT — <project-name>

CRITICAL (fix immediately):
  - [item] [file:line] [why]

HIGH (fix before release):
  - [item] [file:line] [why]

MEDIUM (fix soon):
  - [item] [why]

INFO (consider):
  - [item] [why]

PASSED CHECKS:
  - [count] checks passed
```

## Reference Scripts (in scripts/ folder)

The scripts directory contains:
- `scan-hardcoded-secrets.sh` (regex-based secret scanner)
- `scan-network-security.sh` (HTTP/cleartext detector)
- `scan-storage-security.sh` (SharedPreferences misuse)
- `check-dependencies.sh` (pub outdated wrapper with formatting)

Run each from the project root.

## What This Skill Does NOT Do

- Does NOT replace professional pentest for apps handling money/health/sensitive PII
- Does NOT do dynamic analysis (running the app with instrumentation)
- Does NOT do reverse engineering of competitor APKs
- Does NOT verify backend security (server-side issues need separate audit)

## Strict Rules

- DO scan with EVERY release, not just major versions
- DO NOT add `// ignore_for_file` to hide security warnings, fix the underlying issue
- DO NOT skip `--obfuscate` on release builds, especially for apps with IAP
- DO NOT commit `.env` files, period
- DO NOT downgrade dependencies to silence vulnerability warnings, fix the affected code
