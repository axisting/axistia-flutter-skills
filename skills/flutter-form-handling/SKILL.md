---
name: flutter-form-handling
description: Implements form state management and validation in Flutter with Riverpod. Trigger this skill whenever the user says "build a form", "form validation", "text field", "submit button", "multi-step form", "conditional field", "form ekranı", "doğrulama", "validate input", "input field", or any request to collect user input. Covers the Riverpod form state model, TextFormField validator chain, async validation with debounce, conditional fields, submit flow with loading state, keyboard FocusNode chain, and after-submit navigation. Pairs with flutter-error-handling for displaying submission errors and flutter-page-creation for the surrounding page structure.
---

# Flutter Form Handling

Rule: form state belongs in a Riverpod notifier, not in a `StatefulWidget`. Validators are pure functions. Side effects (API calls, navigation) happen in the notifier's `submit()` method, never inside a validator.

## Form State Model

Create a separate form state class for every form. Never reuse a domain model as a form state class — they have different lifecycles and validation rules.

```dart
// lib/features/edit_profile/domain/edit_profile_form_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'edit_profile_form_state.freezed.dart';

@freezed
class EditProfileFormState with _$EditProfileFormState {
  const factory EditProfileFormState({
    @Default('') String displayName,
    @Default('') String email,
    @Default(false) bool isSubmitting,
    String? submitError,             // set after a failed submit
  }) = _EditProfileFormState;
}
```

## Form Notifier

```dart
// lib/features/edit_profile/presentation/providers/edit_profile_form_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'edit_profile_form_provider.g.dart';

@riverpod
class EditProfileForm extends _$EditProfileForm {
  final formKey = GlobalKey<FormState>();

  // FocusNodes owned by the notifier so they are disposed with the provider
  final displayNameFocus = FocusNode();
  final emailFocus = FocusNode();

  @override
  EditProfileFormState build() => const EditProfileFormState();

  @override
  void dispose() {
    displayNameFocus.dispose();
    emailFocus.dispose();
    super.dispose();
  }

  void updateDisplayName(String value) =>
      state = state.copyWith(displayName: value, submitError: null);

  void updateEmail(String value) =>
      state = state.copyWith(email: value, submitError: null);

  Future<void> submit(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;   // run all validators
    formKey.currentState!.save();                     // trigger onSaved callbacks

    // Dismiss keyboard before async work
    FocusScope.of(context).unfocus();

    state = state.copyWith(isSubmitting: true, submitError: null);

    try {
      await ref.read(userRepositoryProvider).updateProfile(
        displayName: state.displayName,
        email: state.email,
      );
      // Navigate on success — check context.mounted before using context
      if (context.mounted) context.pop();
    } on Failure catch (f) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: _mapFailureToMessage(f, context),
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: context.l10n.errorUnknown,
      );
    }
  }

  String _mapFailureToMessage(Failure failure, BuildContext context) {
    return switch (failure) {
      NetworkFailure() => context.l10n.errorNetwork,
      UnauthorizedFailure() => context.l10n.errorUnauthorized,
      _ => context.l10n.errorUnknown,
    };
  }
}
```

## Complete Form Page

> **Page structure note:** The surrounding page structure (`Scaffold`, `SafeArea`, `AppBar`, GoRouter route registration) is owned by `flutter-page-creation`. Apply that skill first to create the page wrapper, then embed the form notifier and `TextFormField`s from this skill inside it. The snippet below is a self-contained illustration only.

```dart
class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(editProfileFormProvider);
    final formNotifier = ref.read(editProfileFormProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editProfileTitle)),
      body: SafeArea(
        child: GestureDetector(
          // Dismiss keyboard when tapping outside any field
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formNotifier.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    focusNode: formNotifier.displayNameFocus,
                    initialValue: formState.displayName,
                    decoration: InputDecoration(
                      labelText: context.l10n.fieldDisplayName,
                    ),
                    textInputAction: TextInputAction.next,  // "next" for all but last
                    onChanged: formNotifier.updateDisplayName,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return context.l10n.validationRequired;
                      }
                      if (v.trim().length < 2) {
                        return context.l10n.validationTooShort(2);
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) =>
                        formNotifier.emailFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    focusNode: formNotifier.emailFocus,
                    initialValue: formState.email,
                    decoration: InputDecoration(
                      labelText: context.l10n.fieldEmail,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,  // "done" for last field
                    onChanged: formNotifier.updateEmail,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return context.l10n.validationRequired;
                      }
                      if (!_isValidEmail(v.trim())) {
                        return context.l10n.validationEmailInvalid;
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => formNotifier.submit(context),
                  ),
                  if (formState.submitError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formState.submitError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: formState.isSubmitting
                        ? null                            // disable during submit
                        : () => formNotifier.submit(context),
                    child: formState.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.buttonSave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(value);
  }
}
```

## Async Validation with Debounce

Use this pattern for fields that check uniqueness against a backend (e.g. username, email already in use). Async validators run on `FormState.validate()` — debounce prevents a new API call on every keystroke.

```dart
// In the notifier — track debounce timer
Timer? _emailDebounce;
String? _emailAsyncError;

void updateEmail(String value) {
  state = state.copyWith(email: value, submitError: null);
  _emailDebounce?.cancel();
  _emailDebounce = Timer(const Duration(milliseconds: 600), () async {
    final exists = await ref.read(authRepositoryProvider).emailExists(value);
    _emailAsyncError = exists ? context.l10n.validationEmailTaken : null;
    // Trigger validator re-run if form is already shown
    // The validator closure will capture _emailAsyncError on next rebuild
  });
}

// In the TextFormField validator
validator: (v) {
  if (v == null || v.trim().isEmpty) return context.l10n.validationRequired;
  if (!_isValidEmail(v.trim())) return context.l10n.validationEmailInvalid;
  return formNotifier.emailAsyncError;   // null = valid, non-null = error message
},
```

Do not fire async validators on every keystroke. Always debounce with ≥400ms.

## Conditional Fields

Show / hide fields based on another field's value using Riverpod state:

```dart
// In the form state
@freezed
class ShippingFormState with _$ShippingFormState {
  const factory ShippingFormState({
    @Default(false) bool shipToDifferentAddress,
    @Default('') String alternateAddress,
    // ...
  }) = _ShippingFormState;
}

// In the widget
Column(
  children: [
    CheckboxListTile(
      value: formState.shipToDifferentAddress,
      title: Text(context.l10n.fieldShipToDifferentAddress),
      onChanged: (v) => formNotifier.toggleAlternateAddress(v ?? false),
    ),
    if (formState.shipToDifferentAddress)
      TextFormField(
        decoration: InputDecoration(
          labelText: context.l10n.fieldAlternateAddress,
        ),
        validator: (v) => formState.shipToDifferentAddress &&
                (v == null || v.trim().isEmpty)
            ? context.l10n.validationRequired
            : null,
      ),
  ],
)
```

The conditional validator is important: only validate the alternate address field when it is visible.

## Keyboard Management Rules

| Situation | Setting |
|-----------|---------|
| Field followed by another field | `textInputAction: TextInputAction.next` |
| Last field in the form | `textInputAction: TextInputAction.done` |
| Moving focus to next field | `onFieldSubmitted: (_) => nextFocus.requestFocus()` |
| Last field triggers submit | `onFieldSubmitted: (_) => notifier.submit(context)` |
| Multi-line text area | `textInputAction: TextInputAction.newline`, `maxLines: null` |
| Dismiss keyboard on tap outside | Wrap form with `GestureDetector(onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque)` |
| Dismiss keyboard before async submit | Call `FocusScope.of(context).unfocus()` inside `submit()` before the await |

## Submit Flow Rules

1. Call `formKey.currentState!.validate()` first. If false, return immediately — do not call the API.
2. Call `formKey.currentState!.save()` to trigger all `onSaved` callbacks (if you use them).
3. Dismiss the keyboard (`FocusScope.of(context).unfocus()`).
4. Set `isSubmitting = true` to disable the button and show a loading indicator.
5. Await the async operation.
6. On success: check `context.mounted` before navigating or showing a SnackBar.
7. On failure: set `isSubmitting = false` and populate `submitError` — do not navigate.

```dart
// context.mounted check is mandatory after every await in a Widget/BuildContext
if (context.mounted) {
  context.pop();
}
```

## Multi-Step Form

Use a single notifier that tracks the current step index and accumulates data across steps:

```dart
@freezed
class OnboardingFormState with _$OnboardingFormState {
  const factory OnboardingFormState({
    @Default(0) int currentStep,
    // Step 1 data
    @Default('') String name,
    // Step 2 data
    @Default('') String email,
    // Final submit state
    @Default(false) bool isSubmitting,
    String? submitError,
  }) = _OnboardingFormState;
}

// In notifier
void nextStep() {
  if (!formKey.currentState!.validate()) return;
  state = state.copyWith(currentStep: state.currentStep + 1);
}

void previousStep() {
  state = state.copyWith(currentStep: state.currentStep - 1);
}
```

Each step has its own `Form` widget with its own `GlobalKey<FormState>`, but they all share the same notifier instance for accumulated data.

## Forbidden Patterns

```dart
// BAD: side effects inside a validator
validator: (v) {
  api.checkEmailExists(v);   // async work in a sync validator — this is a Future<void> fire-and-forget
  return null;
}

// BAD: setState inside submit
void _submit() async {
  setState(() => _isLoading = true);   // use Riverpod form state instead
  await api.save();
  setState(() => _isLoading = false);
}

// BAD: entire form state in one StatefulWidget
class _MyFormState extends State<MyForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  // ...and more state — grows unbounded, impossible to test
}

// BAD: navigating after async without mounted check
await api.save();
context.pop();   // context may be unmounted — runtime error

// BAD: hardcoded validation messages
validator: (v) => v!.isEmpty ? 'Required' : null;  // use context.l10n.validationRequired

// BAD: calling submit from onFieldSubmitted AND the button simultaneously
// Only the button should call submit. onFieldSubmitted on the last field should
// call the same submit method but guard with isSubmitting check.
```
