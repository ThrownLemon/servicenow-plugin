#!/bin/bash
# Shared Playwright verification helper
# Usage: bash sn-verify.sh --url <url> --output <path.png> [--check-console]
#
# Requires: servicenow-cli (configured), Playwright (chromium)

set -euo pipefail

# Parse arguments
URL=""
OUTPUT=""
CHECK_CONSOLE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --check-console) CHECK_CONSOLE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$URL" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: sn-verify.sh --url <url> --output <path.png> [--check-console]" >&2
  exit 1
fi

# Validate instance URL — must match configured instance
CONFIGURED_INSTANCE=$(servicenow-cli info --json 2>/dev/null | jq -r '.instance // empty')
if [ -z "$CONFIGURED_INSTANCE" ]; then
  echo "Error: servicenow-cli not configured" >&2
  exit 1
fi

# BSD sed (macOS default) doesn't accept `\?` in basic regex — use sed -E
# with POSIX extended regex for portability across Linux and macOS.
URL_HOST=$(echo "$URL" | sed -E -n 's|https?://([^/]*).*|\1|p')
EXPECTED_HOST="${CONFIGURED_INSTANCE}.service-now.com"

if [ "$URL_HOST" != "$EXPECTED_HOST" ]; then
  echo "Error: URL hostname '$URL_HOST' does not match configured instance '$EXPECTED_HOST'" >&2
  echo "Refusing to navigate — this prevents session cookie leakage to untrusted domains." >&2
  exit 1
fi

# Session management
SESSION_DIR="$HOME/.servicenow-cli/sessions"
mkdir -p "$SESSION_DIR"
chmod 700 "$SESSION_DIR"
SESSION_FILE="$SESSION_DIR/${CONFIGURED_INSTANCE}.session.json"

# Ensure output directory exists with secure permissions
OUTPUT_DIR=$(dirname "$OUTPUT")
mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR" 2>/dev/null || true

# Build Playwright script
PLAYWRIGHT_SCRIPT=$(mktemp /tmp/sn-pw-XXXXXX.js)
chmod 600 "$PLAYWRIGHT_SCRIPT"

cat > "$PLAYWRIGHT_SCRIPT" << 'PWEOF'
const { chromium } = require('playwright');

(async () => {
  const url = process.env.SN_URL;
  const output = process.env.SN_OUTPUT;
  const sessionFile = process.env.SN_SESSION_FILE;
  const checkConsole = process.env.SN_CHECK_CONSOLE === 'true';
  const instanceHost = process.env.SN_INSTANCE_HOST;

  // Try to use existing session
  let context;
  let browser;
  try {
    const fs = require('fs');
    browser = await chromium.launch({
      args: ['--disable-extensions', '--disable-background-networking']
    });

    if (fs.existsSync(sessionFile)) {
      const sessionData = JSON.parse(fs.readFileSync(sessionFile, 'utf8'));
      const sessionAge = Date.now() - (sessionData.timestamp || 0);
      if (sessionAge < 15 * 60 * 1000) {
        context = await browser.newContext({ storageState: sessionData.state });
      }
    }

    if (!context) {
      // Need fresh login — read credentials from stdin (never env vars)
      const authJson = await new Promise(resolve => {
        let data = '';
        process.stdin.on('data', chunk => data += chunk);
        process.stdin.on('end', () => resolve(data.trim() || null));
        setTimeout(() => resolve(null), 2000);
      });
      if (!authJson) {
        console.error('Error: No valid session and no credentials provided via stdin');
        process.exit(1);
      }
      const auth = JSON.parse(authJson);
      context = await browser.newContext();
      const page = await context.newPage();

      // Navigate to login page
      await page.goto(`https://${instanceHost}/login.do`, { waitUntil: 'networkidle' });

      // Check for MFA — if login redirects to MFA challenge
      if (page.url().includes('mfa') || page.url().includes('2fa')) {
        console.error('MFA_REQUIRED: Please complete MFA manually in a browser');
        await browser.close();
        process.exit(2);
      }

      // Fill login form
      if (auth.auth_type === 'basic') {
        await page.fill('#user_name', auth.username);
        await page.fill('#user_password', auth.password);
        await page.click('#sysverb_login');
        await page.waitForLoadState('networkidle');
      }

      // Save session
      const state = await context.storageState();
      fs.writeFileSync(sessionFile, JSON.stringify({
        state,
        timestamp: Date.now()
      }), { mode: 0o600 });

      await page.close();
    }

    // Navigate to target URL
    const page = await context.newPage();

    // Capture console errors if requested
    const consoleErrors = [];
    if (checkConsole) {
      page.on('console', msg => {
        if (msg.type() === 'error' || msg.type() === 'warning') {
          consoleErrors.push(`[${msg.type()}] ${msg.text()}`);
        }
      });
    }

    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });

    // Take screenshot
    await page.screenshot({ path: output, fullPage: true });
    require('fs').chmodSync(output, 0o600);

    // Output console errors if any
    if (checkConsole && consoleErrors.length > 0) {
      console.log('CONSOLE_ERRORS:');
      consoleErrors.forEach(e => console.log(e));
    }

    await browser.close();
    console.log(`Screenshot saved: ${output}`);

  } catch (err) {
    console.error(`Error: ${err.message}`);
    if (browser) await browser.close();
    process.exit(1);
  }
})();
PWEOF

# Get credentials if session is missing/stale — pipe via stdin (never env vars)
AUTH_JSON=""
if [ ! -f "$SESSION_FILE" ] || [ "$(find "$SESSION_FILE" -mmin +15 2>/dev/null)" ]; then
  AUTH_JSON=$(servicenow-cli config get-auth --confirm 2>/dev/null) || {
    echo "Error: Failed to get credentials from servicenow-cli" >&2
    rm -f "$PLAYWRIGHT_SCRIPT"
    exit 1
  }
fi

# Audit log: Playwright session start
bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/sn-audit.sh" "playwright_start" "navigation" "none" "url=$URL"

# Run Playwright — credentials piped via stdin, never as env vars or CLI args
echo "$AUTH_JSON" | SN_URL="$URL" \
SN_OUTPUT="$OUTPUT" \
SN_SESSION_FILE="$SESSION_FILE" \
SN_CHECK_CONSOLE="$CHECK_CONSOLE" \
SN_INSTANCE_HOST="$EXPECTED_HOST" \
  node "$PLAYWRIGHT_SCRIPT"

EXIT_CODE=$?

# Audit log: Playwright session end
bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/sn-audit.sh" "playwright_end" "screenshot" "none" "output=$OUTPUT"

# Cleanup
rm -f "$PLAYWRIGHT_SCRIPT"

# Schedule screenshot cleanup (1 hour)
(sleep 3600 && rm -f "$OUTPUT" 2>/dev/null) &

exit $EXIT_CODE
