#!/usr/bin/env bash
set -euo pipefail

OUTPUT="/tmp/eval-output/Containerfile"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must be multi-stage (at least 2 FROM statements)
FROM_COUNT=$(grep -c "^FROM" "$OUTPUT" || true)
if [[ "$FROM_COUNT" -lt 2 ]]; then
    echo "FAIL: must use multi-stage build (at least 2 FROM statements), found $FROM_COUNT"
    exit 1
fi

# Final stage must be FROM scratch
if ! tail -n +1 "$OUTPUT" | grep "^FROM" | tail -1 | grep -q "scratch"; then
    echo "FAIL: final stage must be FROM scratch"
    exit 1
fi

# Must target musl
if ! grep -q "musl\|x86_64-unknown-linux-musl" "$OUTPUT"; then
    echo "FAIL: must build for musl target"
    exit 1
fi

# Must copy CA certificates
if ! grep -qi "ca-certificates\|ssl/certs\|ca_certificates" "$OUTPUT"; then
    echo "FAIL: must copy CA certificates into the runtime image for HTTPS support"
    exit 1
fi

# Must have ENTRYPOINT
if ! grep -q "ENTRYPOINT" "$OUTPUT"; then
    echo "FAIL: must set ENTRYPOINT"
    exit 1
fi

echo "PASS"
exit 0
