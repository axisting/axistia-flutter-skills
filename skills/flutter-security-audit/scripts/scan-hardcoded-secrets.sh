#!/bin/bash
# Scans Flutter project for hardcoded secrets and API keys.
# Usage: ./scan-hardcoded-secrets.sh [project_root]
ROOT="${1:-.}"
echo "=== Hardcoded Secrets Scan ==="
echo ""
echo "[1/6] AWS access keys..."
grep -rn --include="*.dart" -E "AKIA[0-9A-Z]{16}" "$ROOT/lib" 2>/dev/null
echo ""
echo "[2/6] Stripe live keys (CRITICAL)..."
grep -rn --include="*.dart" -E "sk_live_[a-zA-Z0-9]{20,}" "$ROOT/lib" 2>/dev/null
echo ""
echo "[3/6] Generic API key patterns..."
grep -rn --include="*.dart" -iE "(api[_-]?key|apikey|secret[_-]?key|access[_-]?token)\s*=\s*['\"][a-zA-Z0-9_\-]{20,}['\"]" "$ROOT/lib" 2>/dev/null | grep -v firebase_options
echo ""
echo "[4/6] JWT tokens..."
grep -rn --include="*.dart" -E "eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+" "$ROOT/lib" 2>/dev/null
echo ""
echo "[5/6] Committed .env files..."
find "$ROOT" -name ".env" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null
echo ""
echo "[6/6] Hardcoded passwords (literal 'password=' or 'pwd=')..."
grep -rn --include="*.dart" -iE "(password|pwd)\s*=\s*['\"][^'\"]{4,}['\"]" "$ROOT/lib" 2>/dev/null | grep -v "TextEditingController" | grep -v "// "
echo ""
echo "Done. Review findings above. Note: firebase_options.dart contains public config keys which are NOT secrets."
