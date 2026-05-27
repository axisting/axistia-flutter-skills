#!/bin/bash
# Scans for insecure storage patterns.
ROOT="${1:-.}"
echo "=== Storage Security Scan ==="
echo ""
echo "[1/3] Sensitive data in SharedPreferences..."
grep -rn --include="*.dart" -E "SharedPreferences.*\.(setString|setBool|setInt).*['\"](token|password|secret|jwt|apiKey|auth)" "$ROOT/lib" 2>/dev/null
grep -rn --include="*.dart" -E "prefs\.(setString|setBool|setInt).*['\"](token|password|secret|jwt|apiKey|auth)" "$ROOT/lib" 2>/dev/null
echo ""
echo "[2/3] Unencrypted Hive boxes with sensitive names..."
grep -rn --include="*.dart" -E "Hive\.openBox\(['\"](auth|token|secret|user_credentials|password)" "$ROOT/lib" 2>/dev/null
echo ""
echo "[3/3] External storage writes (Android)..."
grep -rn --include="*.dart" -E "getExternalStorageDirectory" "$ROOT/lib" 2>/dev/null
echo ""
echo "Done. Sensitive data should use flutter_secure_storage instead."
