#!/usr/bin/env bash
set -euo pipefail

OUTPUT="/tmp/eval-output/module.nix"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must define options
if ! grep -q "options\|mkOption" "$OUTPUT"; then
    echo "FAIL: must define options using mkOption"
    exit 1
fi

# Must have enable option
if ! grep -q "enable" "$OUTPUT"; then
    echo "FAIL: must have enable option"
    exit 1
fi

# Must have port option
if ! grep -q "port" "$OUTPUT"; then
    echo "FAIL: must have port option"
    exit 1
fi

# Must have config section
if ! grep -q "config\s*=" "$OUTPUT"; then
    echo "FAIL: must have config section implementing the options"
    exit 1
fi

# Must define systemd service
if ! grep -q "systemd.services" "$OUTPUT"; then
    echo "FAIL: must define systemd.services entry"
    exit 1
fi

# Must have mkIf or conditional on enable
if ! grep -q "mkIf\|lib.mkIf\|if cfg.enable\|if config.services.my-api.enable" "$OUTPUT"; then
    echo "FAIL: service must be conditional on enable option (use mkIf)"
    exit 1
fi

echo "PASS"
exit 0
