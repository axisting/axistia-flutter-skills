#!/bin/bash
# Scans for network security issues.
ROOT="${1:-.}"
echo "=== Network Security Scan ==="
echo ""
echo "[1/4] HTTP (non-HTTPS) URLs in Dart..."
grep -rn --include="*.dart" -E "['\"]http://[^'\"]+['\"]" "$ROOT/lib" 2>/dev/null | grep -v "127.0.0.1" | grep -v "localhost" | grep -v "// "
echo ""
echo "[2/4] iOS NSAppTransportSecurity exceptions..."
if [ -f "$ROOT/ios/Runner/Info.plist" ]; then
  grep -A2 "NSAllowsArbitraryLoads" "$ROOT/ios/Runner/Info.plist" 2>/dev/null
fi
echo ""
echo "[3/4] Android cleartext traffic..."
if [ -f "$ROOT/android/app/src/main/AndroidManifest.xml" ]; then
  grep -n "usesCleartextTraffic" "$ROOT/android/app/src/main/AndroidManifest.xml" 2>/dev/null
fi
echo ""
echo "[4/4] Missing network_security_config..."
if [ ! -f "$ROOT/android/app/src/main/res/xml/network_security_config.xml" ]; then
  echo "  WARNING: No network_security_config.xml found. Recommended for production Android apps."
fi
echo ""
echo "Done."
