---
name: flutter-iap-revenuecat
description: Implements in-app purchases and subscriptions in Flutter using RevenueCat. Trigger this skill whenever the user mentions IAP, paywall, subscription, RevenueCat, purchases_flutter, entitlements, restore purchases, monetization, Pro features, or any project that has purchases_flutter in pubspec. Covers SDK initialization, entitlement-based feature gating (never product IDs), paywall display via purchase_ui_flutter, sandbox testing on iOS and Android, restore purchases UX, webhook setup for backend sync, and the most common bugs (missing offerings, sandbox slowness, missing entitlement after purchase, paywall not loading). Critical because broken IAP means broken revenue.
---

# Flutter RevenueCat IAP

The goal: a paywall that works on iOS, Android, and macOS, with subscriptions and one-time purchases, with proper entitlement gating, with offer codes and promo support, with backend sync via webhook.

## Required Packages

```yaml
dependencies:
  purchases_flutter: ^latest        # Core SDK
  purchases_ui_flutter: ^latest     # Optional, for dashboard-configured paywalls
```

Pre-check before adding: the user must have created a RevenueCat account at https://app.revenuecat.com, configured iOS and Android apps in App Store Connect / Play Console, and uploaded the App-Specific Shared Secret (iOS) and Google Play Service Account JSON (Android) to RevenueCat. Without these, no purchases will validate.

## Initialization

In `main.dart`, before `runApp`:

```dart
import 'package:purchases_flutter/purchases_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use debug logs during development
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration configuration;
  if (Platform.isIOS || Platform.isMacOS) {
    configuration = PurchasesConfiguration('appl_YOUR_IOS_API_KEY');
  } else if (Platform.isAndroid) {
    configuration = PurchasesConfiguration('goog_YOUR_ANDROID_API_KEY');
  } else {
    throw UnsupportedError('Platform not supported');
  }
  await Purchases.configure(configuration);

  runApp(const MyApp());
}
```

API keys come from RevenueCat dashboard → Project settings → API keys. Use the PUBLIC keys (start with `appl_` or `goog_`). The SECRET key is for backend only, never in client code.

## Identify the User (Optional but Recommended)

Anonymous users are tracked by RevenueCat's anonymous ID. When the user signs in (Firebase, Supabase, whatever), call `logIn` so purchases follow them across devices:

```dart
final logInResult = await Purchases.logIn(firebaseUser.uid);
final customerInfo = logInResult.customerInfo;
// logInResult.created is true if this is a new RevenueCat user
```

On sign out: `await Purchases.logOut();`

## Feature Gating: Entitlements, NOT Product IDs

The single most important RevenueCat concept. NEVER check `if (productId == 'pro_monthly')` in your code. Always check entitlements.

In RevenueCat dashboard, define an entitlement (e.g., `pro`). Attach multiple products to it: `pro_monthly`, `pro_annual`, `pro_lifetime`, future `pro_2025_promo`. Your code only ever knows about `pro`.

```dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_providers.g.dart';

@riverpod
Stream<CustomerInfo> customerInfoStream(CustomerInfoStreamRef ref) async* {
  // Initial fetch
  yield await Purchases.getCustomerInfo();
  // Listen for updates (purchases, renewals, cancellations from other devices)
  await for (final update in Purchases.addCustomerInfoUpdateListener.stream) {
    yield update;
  }
}

@riverpod
bool isProUser(IsProUserRef ref) {
  final customerInfo = ref.watch(customerInfoStreamProvider).valueOrNull;
  return customerInfo?.entitlements.all['pro']?.isActive ?? false;
}
```

In a widget:
```dart
final isPro = ref.watch(isProUserProvider);
if (isPro) {
  return ProOnlyFeature();
} else {
  return UpgradeToProBanner();
}
```

## Displaying the Paywall

Two options.

### Option A: Dashboard-configured paywall (recommended for solo founders)

Configure the paywall design in RevenueCat dashboard, no Flutter UI code needed.

```dart
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

await RevenueCatUI.presentPaywall(
  offering: await Purchases.getOfferings().then((o) => o.current!),
);
```

Pros: A/B testing, remote updates, no app re-submission to change copy.
Cons: design limited to RevenueCat templates.

### Option B: Custom Flutter paywall

Fetch offerings, build your own UI:

```dart
Future<Offering?> _loadOffering() async {
  try {
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  } on PlatformException catch (e) {
    // No offerings configured, or product IDs mismatch
    return null;
  }
}

Future<bool> _purchase(Package package) async {
  try {
    final result = await Purchases.purchasePackage(package);
    return result.customerInfo.entitlements.all['pro']?.isActive ?? false;
  } on PlatformException catch (e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);
    if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
      // User backed out, do not show error
      return false;
    }
    // Real error, show to user
    rethrow;
  }
}
```

If `offerings.current` is null, something is wrong: products not configured in RevenueCat, product IDs mismatch with stores, or sandbox/production mismatch. Tell the user to check RevenueCat dashboard, do not silently hide the paywall.

## Restore Purchases (Mandatory)

Apple App Review Guideline 3.1.1 requires a "Restore Purchases" button on any paywall. Without it, the app gets rejected.

```dart
Future<void> _restorePurchases() async {
  try {
    final customerInfo = await Purchases.restorePurchases();
    if (customerInfo.entitlements.all['pro']?.isActive ?? false) {
      // Show success
    } else {
      // Show "No previous purchases found"
    }
  } on PlatformException catch (e) {
    // Show error
  }
}
```

Always provide a "Restore" button at the bottom of the paywall and in account settings.

## Sandbox Testing

### iOS
1. Create a sandbox tester in App Store Connect → Users and Access → Sandbox Testers
2. Sign out of App Store on the device (Settings → App Store → sign out)
3. Run app, attempt purchase, iOS will prompt for sandbox credentials
4. Sandbox is SLOW (purchase can take 10+ seconds), this is normal, do not assume your code is broken
5. iOS 13 and earlier: sandbox purchases must be on a real device, not simulator

### Android
1. Add tester emails in Play Console → License testing
2. Upload an APK to internal testing track
3. Install via Play Store (not direct APK install), tester accounts get sandbox prices
4. License testers can purchase repeatedly without real charges

### Verifying via Code
```dart
await Purchases.setLogLevel(LogLevel.debug);
// Watch console for [Purchases] log lines during purchase
```

## Webhook for Backend Sync

For accurate subscription status on the server (after refunds, cancellations, billing issues), set up a RevenueCat webhook:

1. RevenueCat dashboard → Project settings → Integrations → Webhooks
2. Add endpoint URL (Cloud Function, Supabase Edge Function, custom backend)
3. Verify signature using the webhook secret on your endpoint
4. Update user's subscription status in your database on relevant events: `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`, `BILLING_ISSUE`

Without a webhook, your backend can become out of sync when users cancel from settings or get refunds.

## Common Bugs and Diagnosis

### "No offerings configured" or `offerings.current == null`
1. Are products created in App Store Connect / Play Console?
2. Are they linked in RevenueCat → Products?
3. Are they added to an Offering and is one marked "Current"?
4. Are product IDs IDENTICAL between store and RevenueCat (case-sensitive)?

### Purchase succeeds but entitlement is false
1. Is the product attached to the right entitlement in RevenueCat?
2. Is the iOS App-Specific Shared Secret uploaded to RevenueCat?
3. Did you check `entitlements.all['pro']?.isActive`, not `entitlements.active['pro']`?

### Sandbox prices differ from App Store Connect prices
This is normal in sandbox, StoreKit Test, and TestFlight. Production prices follow ASC.

### `BillingResponseCode.developerError` on Android
Wrong API key, or app is signed with debug key but Play Store expects release key. Verify the API key is the Android (`goog_`) key, not iOS.

### Offer codes don't redeem
- iOS: redirect user to App Store via `Purchases.presentCodeRedemptionSheet()` (deprecated on Flutter SDK as of latest, may need manual deep link)
- Android: handled automatically by Play Store

### App rejected: "Subscription terms not clear"
The paywall must show, BEFORE purchase: price, billing period, "auto-renewing" wording, link to Terms of Use, link to Privacy Policy, mention of how to cancel. Apple is strict about this in 2026.

## RevenueCat App Store Review Checklist

Before submitting an app with IAP to App Store:
- [ ] Paywall shows price, period, "auto-renewing subscription" wording before purchase
- [ ] Terms of Use link visible on paywall (mandatory per Apple)
- [ ] Privacy Policy link visible on paywall (mandatory)
- [ ] Restore Purchases button visible on paywall AND in settings
- [ ] Subscription products configured in App Store Connect with Apple review notes explaining what's locked
- [ ] At least one product is set as PRIMARY subscription
- [ ] Cancellation instructions documented in app (Settings → Apple ID → Subscriptions)
- [ ] Sandbox test completed end-to-end on a real device with a sandbox account

For Android Play Store:
- [ ] Data Safety form lists what RevenueCat collects (subscription status)
- [ ] Subscription products published, not just created
- [ ] Promotional offers tested (if any)

## Strict Rules

- DO NOT check product IDs in business logic, always check entitlements
- DO NOT skip Restore Purchases, Apple will reject the app
- DO NOT call Purchases methods before `Purchases.configure()`, they will silently fail
- DO NOT put secret API keys in client code, only public (appl_/goog_) keys
- DO NOT test on iOS Simulator, sandbox purchases require a real device for iOS 13 and earlier; even on newer iOS the experience differs
- DO NOT assume `customerInfo.entitlements.all[X].isActive` is real-time, listen to `Purchases.addCustomerInfoUpdateListener` for updates
- DO NOT hardcode subscription prices in the UI, fetch from Offering and display `package.storeProduct.priceString`

## IAP Error Handling

Purchase failures (network timeouts, billing errors, entitlement validation failures) must be mapped to domain `Failure` types before surfacing to the UI.

**Critical special case:** `PurchasesErrorCode.purchaseCancelledError` is NOT an error. The user deliberately backed out of the purchase. Handle it silently (return false, show no SnackBar, log nothing to analytics as an error).

For all other `PlatformException` codes from RevenueCat, consult `flutter-error-handling` for:
- Wrapping `PlatformException` into `NetworkFailure`, `UnknownFailure`, etc.
- SnackBar vs inline error vs full-screen error decision for purchase flows
- Retry logic for transient network failures during entitlement fetch
