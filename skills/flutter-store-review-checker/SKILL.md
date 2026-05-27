---
name: flutter-store-review-checker
description: Pre-submission audit for Flutter apps targeting Apple App Store and Google Play Store. Trigger this skill when the user mentions "submit to App Store", "ready to publish", "TestFlight", "App Store review", "app rejected", "Guideline 5.1.1", "Guideline 4.8", "privacy manifest", "PrivacyInfo.xcprivacy", "Data Safety", "Privacy Policy", or before any production release. Runs a checklist covering App Privacy labels, privacy manifests, third-party SDK signatures, login requirements (5.1.1 e-commerce browse-before-login), Apple Sign-In requirement when offering social auth (4.8), subscription terms transparency, screenshot requirements, age rating, and Play Store Data Safety form. Identifies blockers BEFORE the rejection email arrives.
---

# Flutter App Store + Play Store Review Checker

This skill runs as a pre-flight audit. Its job is to find rejection causes BEFORE submitting, not after.

## Run Order

1. Read `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`
2. Run the Apple checklist (most strict)
3. Run the Android checklist
4. Output a single combined report with blockers, warnings, and "okay" items

Do not just list rules abstractly. For each item, ACTUALLY check the project's files and report status: PASS, FAIL, NEEDS_REVIEW.

## Apple App Store Checklist (2026 Rules)

### Privacy

#### App Privacy Labels (App Store Connect)
- [ ] Privacy labels submitted in App Store Connect, NOT empty
- [ ] Every SDK that collects data is reflected: Firebase Analytics, Crashlytics, RevenueCat, AdMob, Google Sign-In, Apple Sign-In, third-party tracking SDKs
- [ ] "Data Linked to User" vs "Data Not Linked" answered correctly
- [ ] "Used for Tracking" answered: if app uses IDFA via AdMob/Facebook SDK, this is YES
- [ ] Privacy Policy URL set in App Information section

Action item: open App Store Connect → App Privacy → Get Started, run through the wizard.

#### PrivacyInfo.xcprivacy Manifest
Since 2024, Apple REQUIRES a privacy manifest for any third-party SDK that accesses certain "required reason APIs". As of 2026, missing manifests cause automatic rejection.

Check:
- [ ] `ios/Runner/PrivacyInfo.xcprivacy` exists
- [ ] Manifest declares which "required reason API" categories the app uses
- [ ] Common ones: `NSPrivacyAccessedAPICategoryFileTimestamp` (file modification timestamps), `NSPrivacyAccessedAPICategoryUserDefaults`, `NSPrivacyAccessedAPICategorySystemBootTime`, `NSPrivacyAccessedAPICategoryDiskSpace`
- [ ] For each, a valid `NSPrivacyAccessedAPITypeReasons` code is listed

Third-party SDK signatures:
- [ ] All "privacy-impacting SDKs" in pubspec are versioned to releases that include their own PrivacyInfo.xcprivacy and signature
- [ ] Common ones to verify on pub.dev: Firebase SDKs (firebase_core, firebase_auth, etc.), Google Mobile Ads, Facebook SDK, Crashlytics

If user is unsure, point them to https://developer.apple.com/documentation/bundleresources/privacy_manifest_files

#### Tracking (ATT)
If the app uses any tracking SDK (AdMob, Meta, AppsFlyer, Adjust):
- [ ] `NSUserTrackingUsageDescription` in Info.plist with clear explanation
- [ ] `AppTrackingTransparency` permission requested before any tracking SDK initializes
- [ ] App still functions if user declines ATT
- [ ] App Privacy label "Used for Tracking" = YES for the relevant data types

If no tracking:
- [ ] No tracking SDKs in pubspec
- [ ] No `NSUserTrackingUsageDescription` (Apple flags unused permissions)

### Login and Account

#### Guideline 5.1.1 (most common rejection)
"Apps may not require users to enter personal information to function, except when directly relevant to the core functionality of the app or required by law."

Check the app's login flow:
- [ ] Can the user BROWSE main content without signing in? (e-commerce, content discovery, social feeds must allow guest browsing)
- [ ] Is login required ONLY for account-specific features (purchases, saved items, social posting)?
- [ ] If login is gated at app open, is the app's purpose account-based (banking, fitness tracking, productivity)?

If a marketplace, content app, or browser-style app forces login before showing anything, REJECTION IS LIKELY.

#### Guideline 4.8 (Sign in with Apple)
If the app offers Google Sign-In, Facebook Login, or any third-party sign-in:
- [ ] Sign in with Apple is ALSO offered with equal prominence
- [ ] Apple Sign-In button is shown at the same level as other sign-in options (not hidden in "more options")

If only email/password auth: 4.8 does not apply, skip this check.

If `google_sign_in` is in pubspec but `sign_in_with_apple` is not, this is a BLOCKER.

#### Guideline 5.1.1(v) Account Deletion
- [ ] In-app account deletion is implemented (not just "email us")
- [ ] Deletion is reachable from account settings within 3 taps
- [ ] Deletion immediately deletes data OR provides a clear timeline

Missing account deletion is a common rejection since 2022.

### Subscriptions and IAP

#### Subscription Transparency (App Review 3.1.2)
On the paywall, BEFORE the user can tap purchase:
- [ ] Price is visible
- [ ] Billing period is visible (monthly, annual, etc.)
- [ ] "Auto-renewing subscription" wording is present
- [ ] Link to Terms of Use is visible
- [ ] Link to Privacy Policy is visible
- [ ] Free trial length (if any) is visible
- [ ] What's included in the subscription is clearly listed

#### Restore Purchases
- [ ] "Restore Purchases" button on paywall
- [ ] "Restore Purchases" option in account settings

#### Real Products
- [ ] Products are configured in App Store Connect (not just RevenueCat)
- [ ] Products have screenshots/review notes uploaded
- [ ] At least one subscription is marked as the primary subscription

### App Content

#### Age Rating
- [ ] Age rating questionnaire completed in App Store Connect
- [ ] If user-generated content exists, content moderation mechanism is documented
- [ ] If user-to-user contact exists, blocking/reporting is implemented

#### Screenshots
- [ ] Screenshots match the latest version of the app (Apple rejects stale screenshots)
- [ ] Screenshots show actual app UI, not marketing mockups
- [ ] All required device sizes covered: 6.7" iPhone, 6.1" iPhone (optional but recommended), iPad 13" if app supports iPad

#### App Icon
- [ ] No transparency in the icon (Apple flattens with black background, breaks designs)
- [ ] Icon does not include "App Store", "Apple", or other Apple branding
- [ ] Icon is the same in App Store Connect and inside the app

### Technical

#### Build
- [ ] Built with current Xcode version (Apple deprecates old Xcode periodically)
- [ ] Bitcode disabled (deprecated by Apple in 2022)
- [ ] Minimum iOS version reasonable (iOS 13+ usually fine, iOS 15+ better for modern SDKs)

#### Crash Reports
- [ ] No crash on first launch in any region/locale
- [ ] Crashlytics or similar configured
- [ ] No print statements or debug logs in release builds

## Google Play Store Checklist

### Data Safety Form
- [ ] Form completed in Play Console → App content → Data safety
- [ ] Every data type the app collects is listed: device ID, IP, crash logs, purchase history, etc.
- [ ] Encryption in transit declared
- [ ] User can request data deletion (in-app or via documented process)

### Account Deletion
Same as Apple: in-app account deletion required since 2024.

### Target SDK Level
- [ ] `compileSdk` is set to the latest Android version (Android 14+ for 2026)
- [ ] `targetSdk` matches Play Store's minimum requirement (check Play Console, typically Android 13+ in 2026)

### Permissions
- [ ] Every permission in AndroidManifest.xml has a clear use case
- [ ] Sensitive permissions (READ_CONTACTS, ACCESS_FINE_LOCATION, etc.) prompt at runtime, not at install
- [ ] Background location use case is documented in Play Console if used

### Subscriptions
Same general rules as Apple:
- [ ] Restore Purchases button
- [ ] Subscription terms visible on paywall
- [ ] Cancellation instructions documented in the app

### Screenshots and Listing
- [ ] At least 2 screenshots uploaded
- [ ] Feature graphic 1024x500 uploaded
- [ ] Short description and full description filled in

## Cross-Cutting

### Privacy Policy
A hosted Privacy Policy URL is required by BOTH stores. The policy must:
- [ ] Be reachable (not behind login, not 404)
- [ ] List every data type collected and why
- [ ] List every third-party SDK that processes data
- [ ] Provide a contact for data requests
- [ ] Mention GDPR rights if the app is available in EU
- [ ] Mention CCPA rights if available in California

If the user has no Privacy Policy yet, that is a BLOCKER. Tools like https://app-privacy-policy-generator.firebaseapp.com or a custom one can fix this in 15 minutes.

### Localized App Store Metadata
- [ ] App name, subtitle, description, keywords translated for each locale the app supports
- [ ] Screenshots localized (Turkish app should have Turkish screenshots, not English ones)

## Output Format

When this skill runs, produce a structured report:

```
APPLE APP STORE — Status: <READY|BLOCKED|NEEDS_REVIEW>
  BLOCKERS (must fix before submission):
    - [item] [why]
  WARNINGS (likely to delay review):
    - [item] [why]
  PASS:
    - [count] checks passed

GOOGLE PLAY STORE — Status: <READY|BLOCKED|NEEDS_REVIEW>
  BLOCKERS:
    ...
  WARNINGS:
    ...
  PASS:
    - [count] checks passed
```

Do not output the full checklist as-is, only the items that need attention plus a count summary.

## Volkan-Specific Context

Volkan went through HST iOS submission recently and dealt with:
- TestFlight issues likely rooted in incomplete banking setup
- W-8BEN tax form
- ATT tracking declaration
- RevenueCat configured for auto-renewable + one-time purchases in multiple currencies

When auditing HST, double-check that banking and tax forms are complete in App Store Connect → Agreements, Tax, and Banking. Missing tax info blocks paid app distribution even if the app passes review.
