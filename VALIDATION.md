# Validation status

## Executed in this workspace

- JavaScript module syntax check: PASS (Node).
- Chromium mobile-viewport smoke test with external HTTPS requests blocked: PASS.
  - Bundled editor initializes without external engine downloads.
  - Native-format scan fixture is accepted.
  - Four corners and 12.00 m² are shown for the 4 × 3 m fixture.
  - Add chair creates one furniture item.
  - Unimplemented AR-photo control is hidden.
  - Invalid scan input is rejected.
  - No uncaught page JavaScript errors.
- Three.js files compared with the pinned npm package: PASS.
- Project YAML and workflow YAML parse: PASS.

## Added, not executed here

- XCTest tests for rotated canonical coordinates, area/perimeter, valid concave/reversed rooms, invalid crossings/duplicates/zero-area/non-finite/non-planar rooms, and JSON serialization.
- macOS GitHub Actions compilation and simulator test workflow.

## Not available in this Linux workspace

- Swift/iOS SDK compilation, XcodeGen project generation, WKWebView execution on iOS.
- Real camera permission flows, ARKit tracking/floor detection, interruption recovery and measurement accuracy.
- Signing, installation, TestFlight or App Store distribution.

The browser fixture matches the intended Swift output shape; it is not a scan produced by executing the Swift scanner. The first macOS build and physical iPhone acceptance checks in README.md remain required. No claim of full HelloXR feature parity is made.
