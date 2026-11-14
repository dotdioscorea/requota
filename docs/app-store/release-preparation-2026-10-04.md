# Requota 1.0 release preparation

Build **1.0 (23)** is available to the existing internal and external TestFlight groups. Apple approved external beta review. Its binary source is `88326c6c133f849f53099984aa3250c1a5df9bdd`, tagged `testflight/1.0-23`. [PR #12](https://github.com/dotdioscorea/requota/pull/12) fixes Codex reconnect and sign-in failure reporting. [Build 23 validation](../testflight-build-23.json) records the exact package, tests and distribution state. The [investigation notes](../codex-signin-fix-2026-11-14.md) describe the reproduced rejection and reporting gap. The earlier live unused-week activation countdown check remains pending.

## App Store Connect

The [version draft](https://appstoreconnect.apple.com/apps/6818509879/distribution/ios/version/inflight) has build 23 selected and remains **Prepare for Submission**. No App Store review submission or public release was made. Release is set to **manual**.

- English UK title, subtitle, description, promotional text, keywords, support URL and copyright are saved.
- Six iPhone and five iPad screenshots finished processing, in the agreed order.
- Price is free in all 175 territories. All territories and future territories are selected, subject to Apple's distribution requirements.
- Categories are Utilities and Productivity. The age questionnaire produces 4+ with regional exceptions.
- The privacy policy URL is saved and the approved **Data Not Collected** responses are published.
- The existing trader declaration is retained. The signed package declares no non-exempt encryption.
- Reviewer contact details and [Demo access instructions](review-notes.txt) are saved. Private reviewer details remain outside this public repository.

Content Rights is saved as “Yes” on the owner’s confirmation of the necessary rights to third-party content.

## Validation

224 unit checks and one live Codex check passed out of 231 executed, with six other opt-in live checks skipped. Three native UI checks passed: both Codex sign-in options and cancellation, the rejection/report screen with retained evidence, and duplicate Claude account reconnect. The corrected native simulator reconnect completed with a verified matching identity, current usage and saved connection. The authorization step reused a Chrome identity; the native callback, token exchange, identity, usage and persistence ran in Requota. Physical-device testing and other providers’ live authorization were not repeated.

The exact uploaded IPA was checked for matching app/widget versions, distribution signatures, the shared App Group, both privacy manifests, background modes/task identifiers, the encryption declaration and exclusion of test fixtures and the temporary authorization bridge. It was built with the iOS 26.5 SDK. See [the release record](../testflight-build-23.json) for its hash and Apple status.

## Administration

`scripts/prepare-app-store.py` supports `metadata`, `screenshots`, `pricing`, `availability`, `select-build` and `verify`. Writes require `--apply` and an editable, unsubmitted version. Its API credentials are read from ignored `.release/apple.json`. It does not submit or release an App Store version.

App Store review submission and eventual manual release are separate actions.
