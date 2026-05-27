#!/bin/bash
# Finds candidate hardcoded strings in Flutter widgets.
# Usage: ./audit-hardcoded-strings.sh [project_root]
ROOT="${1:-.}"
echo "Scanning $ROOT/lib for hardcoded strings..."
grep -rn --include="*.dart" -E "(Text|Tooltip|AppBar.*title:|Semantics.*label:|SnackBar.*content:|AlertDialog.*title:|hintText:|labelText:)\s*\(?\s*['\"]" "$ROOT/lib" \
  | grep -v "AppLocalizations" \
  | grep -v "context.l10n" \
  | grep -v "// ignore: l10n"
