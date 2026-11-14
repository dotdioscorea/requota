# Codex reconnect correction — 14 November 2026

A saved Codex connection could not reconnect because its authorization request included `id_token_hint`. OpenAI returned `invalid_request` with a cryptographic-processing error. Requota incorrectly treated every OAuth error callback as user cancellation, hid the provider rejection and did not offer a problem report.

## Reproduction and correction

- A fresh authorization with the existing native client, four identity/offline scopes, nonce and S256 PKCE succeeded. Token, signing-key and usage requests returned HTTP 200.
- Reconnecting that saved identity with the previous request builder reproduced the provider rejection and the app’s misleading cancellation message.
- Removing the hint for the native Codex client allowed reconnect to complete, verify the same subject and workspace, fetch current usage and replace the existing saved connection while preserving its settings.
- The documented hint behavior of older dynamically registered clients remains separate. Identity signature, issuer, audience, expiry, nonce, callback state and PKCE validation remain in place.

Authorization used an existing signed-in Chrome identity for the native simulator attempt; the callback, token exchange, identity verification, usage requests and persistence ran in Requota. A temporary local test bridge was removed before committing. This does not claim a complete sign-in through every provider-owned iPhone web screen or a physical-device test. No CLI refresh token was consumed or replaced.

## Failure evidence

No GitHub issues or submitted debug bundles were available at investigation start. The available simulator log had no prior Codex failure; the affected iPhone’s logs were unavailable. Reproduction confirmed a diagnostic gap: an OAuth `invalid_request` was recorded as cancellation, and only usage-parser failures received durable response-schema capture.

Provider rejections now return to the app as errors. Unexpected sign-in failures offer a report action. Diagnostics retain sign-in failure stages, allowlisted OAuth error codes, HTTP status and response field types locally for up to 30 days, limited to 20 distinct observations. Successful polling does not displace this archive. Token response values, authorization codes, state, identity hints and provider error descriptions are excluded. Unknown response field names are hashed. Reports prefill the redacted evidence, with an optional full bundle.

Reconnect failures also add an observed account event. Cancellation and choosing a different identity do not prompt a bug report. A failed reconnect does not replace saved credentials or readings.

Reports still require the user to submit them on GitHub. There is no automatic-upload backend. The privacy page describes the expanded local capture.

## Validation

Regression checks cover native reconnect requests without identity hints, validated provider rejections, genuine cancellation, ambiguous or forged callbacks, token-error decoding, refresh-token revocation, report prompts, archive retention and redaction, and observed-event persistence. Release-specific test counts and Apple distribution status are recorded in the build validation file.

The final iOS 26.5 run passed 224 unit checks and one live Codex check (231 test cases, six other opt-in live checks skipped). Three native UI checks passed: both Codex browser options and cancellation, the rejection/report screen with retained evidence, and duplicate Claude account reconnect. The rejection screen was visually inspected.
