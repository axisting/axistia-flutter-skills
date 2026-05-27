# axistia-flutter-skills

Curated Claude/Copilot skills for Flutter mobile development. Built for solo founders and small teams shipping production apps.

These skills enforce a consistent stack across all Flutter projects: Riverpod 3.x codegen, Freezed 3.x sealed classes, GoRouter, Dio, Firebase OR Supabase, RevenueCat, l10n from day one, theme-aware widgets, responsive layouts, App Store / Play Store ready.

## Quick Install

One command, installs to both VS Code Copilot and Claude Code:

```bash
curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash
```

Target a specific tool only:

```bash
# VS Code Copilot only
curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash -s -- --target=copilot

# Claude Code only
curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash -s -- --target=claude
```

After install, restart VS Code (and/or Claude Code) so the skills are picked up.

## Skills Included

| Skill | Purpose | Triggers On |
|-------|---------|-------------|
| `flutter-project-detector` | Master router, reads pubspec.yaml and points to the right specialist skills | Any Flutter task |
| `flutter-auth-firebase` | Firebase auth with Apple Sign-In done right (correct nonce + authorizationCode sequence) | `firebase_auth` in pubspec, "Sign in with Apple", "invalid-credential" errors |
| `flutter-auth-supabase` | Supabase auth with Apple Sign-In, signInWithIdToken, OAuth flow | `supabase_flutter` in pubspec, "Nonces mismatch" |
| `flutter-iap-revenuecat` | In-app purchases, subscriptions, paywall, entitlements, restore | `purchases_flutter` in pubspec, "paywall", "subscription" |
| `flutter-l10n-enforcer` | Forces ARB-based localization, no hardcoded strings, parallel language sync | Any user-visible string in a widget |
| `flutter-responsive-design` | MediaQuery + LayoutBuilder + Flexible, no hardcoded screen widths | Any widget with width/height |
| `flutter-theme-aware` | ThemeData enforcement, ColorScheme tokens, no hardcoded colors | Any Color or TextStyle in widget code |
| `flutter-new-project-starter` | Bootstraps a new Flutter project with the full stack | "new project", "start from scratch" |
| `flutter-page-creation` | Page file placement, Scaffold anatomy, scroll strategy, Riverpod state skeleton, done-checklist | "create a screen", "add a page", "new view", "settings screen" |
| `flutter-error-handling` | Domain error model (Freezed sealed), Dio mapping, AsyncValue UI patterns, retry logic | "handle error", "API fails", "error state", "retry", AsyncValue error |
| `flutter-form-handling` | Riverpod form state, TextFormField validators, async validation, submit flow, keyboard FocusNode chain | "build a form", "form validation", "text field", "submit button" |
| `flutter-store-review-checker` | Pre-submission audit for App Store + Play Store (privacy manifest, ATT, 4.8, 5.1.1) | "submit to App Store", "ready to publish" |
| `flutter-security-audit` | OWASP Mobile Top 10 (2024) scan: secrets, network, storage, deps | "security audit", "before release" |
| `flutter-package-version-checker` | Verifies dependencies are current, flags abandoned packages | "update packages", "pub outdated" |
| `mobile-app-ui-design` | Designs high-quality mobile UI/UX screens, flows, and components | "design a screen", "app mockup", "mobile UI", "onboarding flow", "make this look better" |

## How They Work Together

```
User: "Add Apple Sign-In to my app"
  └─ flutter-project-detector runs first
       └─ reads pubspec.yaml, sees firebase_auth + sign_in_with_apple
       └─ loads flutter-auth-firebase skill
              └─ writes correct rawNonce + hashedNonce + authorizationCode sequence

User: "Build a settings screen"
  └─ flutter-project-detector → loads:
       ├─ flutter-l10n-enforcer (forces ARB for every string)
       ├─ flutter-theme-aware (forces Theme.of(context).colorScheme.*)
       └─ flutter-responsive-design (forces SafeArea + LayoutBuilder)

User: "Build a settings screen with a save button"
  └─ flutter-project-detector → loads:
       ├─ flutter-page-creation (page skeleton + done-checklist)
       ├─ flutter-form-handling (form state + submit flow + keyboard)
       ├─ flutter-error-handling (AsyncValue error state + retry)
       ├─ flutter-theme-aware (colors/text styles from Theme)
       ├─ flutter-l10n-enforcer (all strings via ARB)
       └─ flutter-responsive-design (SafeArea + LayoutBuilder)

User: "Is this app ready to ship?"
  └─ Runs flutter-store-review-checker
       └─ Audits privacy manifest, ATT, login flow, 4.8, IAP transparency
       └─ Then flutter-security-audit
       └─ Then flutter-package-version-checker
```

## AGENTS.md (Per-Project Defaults)

The `instructions/AGENTS.md` file contains cross-cutting rules that apply to every Flutter project:

- Never use em dash (regular hyphen, comma, parenthesis, colon instead)
- Riverpod 3.x codegen by default
- Feature-first folder structure
- Run `dart format . && flutter analyze && flutter test` before every commit
- And more (see file)

After install, the script saves AGENTS.md to `~/.axistia/AGENTS.md`. Copy it to each project root manually:

```bash
cp ~/.axistia/AGENTS.md /path/to/your/flutter/project/AGENTS.md
```

This way each project has the rules in its repo and they ship with the codebase.

## Manual Install (Alternative)

If you prefer manual install:

```bash
# Clone the repo
git clone https://github.com/axisting/axistia-flutter-skills.git
cd axistia-flutter-skills

# For VS Code Copilot
mkdir -p ~/.copilot/skills
cp -r skills/* ~/.copilot/skills/

# For Claude Code
mkdir -p ~/.claude/skills
cp -r skills/* ~/.claude/skills/

# Copy AGENTS.md to a project
cp instructions/AGENTS.md /path/to/your/project/AGENTS.md
```

## Updating

Just re-run the install script. It overwrites existing skill directories with the latest version:

```bash
curl -sSL https://raw.githubusercontent.com/axisting/axistia-flutter-skills/main/install.sh | bash
```

## Customizing

Each skill is a self-contained `SKILL.md` file. Open, edit, save. Some skills also have a `scripts/` subdirectory with helper shell scripts (l10n auditor, security scanners).

To fork for your own team:
1. Fork this repo on GitHub
2. Edit `instructions/AGENTS.md` with your team's defaults
3. Adjust skills as needed
4. Update `install.sh` REPO_URL to point to your fork
5. Run install from your fork's URL

## What This Is NOT

- Not an alternative to Anthropic's official `code-review`, `frontend-design`, or other generic skills. Use those for non-Flutter work.
- Not a substitute for professional code review on apps handling money, health, or sensitive PII.
- Not a Flutter learning resource. Assumes intermediate-to-senior Flutter knowledge.

## Testing the Skills

After install, open a Flutter project in VS Code and try these prompts:

```
"What stack does this project use?"
→ Should trigger flutter-project-detector

"Add Sign in with Apple to this project"
→ Should trigger flutter-auth-firebase or flutter-auth-supabase (based on pubspec)

"Is this app ready for App Store submission?"
→ Should trigger flutter-store-review-checker

"Update all my packages"
→ Should trigger flutter-package-version-checker

"Build a paywall screen"
→ Should trigger flutter-iap-revenuecat
```

If a skill doesn't trigger, the issue is usually that VS Code didn't pick up the new files. Restart VS Code completely (not just reload window).

## Built By

[Volkan Demir](https://axisting.com) ([Axistia](https://axistia.org) ) for use across:
- [Habit Score Tracker](https://habitscoretracker.axistia.org) (HST)
- [Livestock Manager](https://livestockmanager.axistia.org)
- Kap Kurtar
- Meditai
- Weara
- Clendy
- Future Axistia apps

If you find these useful, a star on the repo is appreciated. If you spot bugs or want to suggest a new skill, open an issue.

## License

MIT. Use freely. Modify freely. Ship freely.
