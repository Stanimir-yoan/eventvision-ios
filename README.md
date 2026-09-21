# EventVision iPhone — native scanner milestone

This is an independent iOS **source project**, based on your working EventVision v10.7.4. It is not an installable IPA or a finished replacement for every HelloXR feature. Your Android/GitHub Pages site is unchanged.

## Implemented

- Native ARKit camera view, horizontal floor detection, corner placement and undo.
- First corner locks floor height; subsequent points must be on a detected surface within 15 cm of it. Aim at the actual floor, not furniture. The app does not automatically identify which horizontal surface is the floor.
- Metric, Y-up scan contract compatible with `window.EventVisionScan.receive`.
- Validation of duplicate corners, crossings, non-finite points, different floor heights and zero-area rooms.
- Native-to-web handoff into the bundled v10.7.4 floorplan editor, including chair editing.
- Share the raw scan JSON through the iOS share sheet.
- Camera permission handling, tracking-state checks and explicit restart after interruptions. Restart clears corners rather than mixing different tracking origins.
- Bundled Three.js 0.180.0 and license. The native floorplan path does not depend on loading Three.js from the internet.

## Deliberate milestone limits

Native live furniture overlays, AR photos, camera projection export, saved-room relocalization, layout persistence and editor export integration are not implemented here. Their web controls are hidden in the native copy. Share scan exports the room measurement only, not furniture edits. Reload or leaving the editor discards layout edits. Save the scan through Share scan before leaving. The raw scan is otherwise held in memory only.

The native AR session ends when the editor opens. A stored ARKit world coordinate is not a persistent real-world anchor. The next camera milestone needs live native pose/projection data and a deliberate strategy for restoring room alignment; it must not reuse these coordinates in a new session without relocalization.

This is manual corner measurement, not RoomPlan and not a LiDAR mesh scanner. LiDAR is not required, but an ARKit-compatible iPhone is. Minimum deployment target: iOS 16. Portrait only in this milestone.

## Your next step on Windows

1. Extract this ZIP.
2. Create a **separate private GitHub repository** for the iOS app. Upload the contents of `EventVision-iOS` into its root, including `.github/workflows/ios-check.yml`. Do not replace the working GitHub Pages site.
3. Open the repository's **Actions** tab, select **iOS compile and geometry tests**, and choose **Run workflow**. It generates the Xcode project, compiles for iPhone without signing, and runs geometry tests on an iPhone simulator.
4. Keep the result/log if it fails. This workflow is the first actual Apple-platform compilation gate; it was provided but could not be executed in this Linux workspace.
5. After it is green, configure signing on a Mac or macOS build service to install on your phone. This unsigned check does **not** produce an installable iPhone app or upload to TestFlight.

For TestFlight, the later signing stage needs your Apple Developer team, a unique bundle ID, an App Store Connect app record, signing configuration, an app icon and distribution archive. Do not put signing keys in source control. We have not configured or published any of those here.

## Build on a Mac

Install Xcode with iOS support and the XcodeGen project generator, then run from this directory:

```sh
xcodegen generate
open EventVision.xcodeproj
```

Choose a unique bundle identifier instead of `com.example.eventvision`, choose your signing team, connect an iPhone, and run the EventVision scheme. Xcode generates Info.plist from `project.yml`, including the camera explanation. The simulator can run geometry tests but cannot validate physical AR scanning.

## Physical iPhone acceptance checks

- Camera permission: deny, then grant in Settings; the app must recover with Restart.
- Scan a rectangular room clockwise and counterclockwise. Compare known wall lengths and area with a tape measure.
- Undo the first corner and confirm a different floor can be selected.
- Reject duplicate/crossed corners; correct them with Undo.
- Cover the camera or move too fast: adding corners must stop during limited tracking.
- Lock/unlock the phone: require Restart; never silently combine old and new origins.
- Finish and verify the editor shows the same corner count and area; add, move, rotate and delete chairs.
- Share scan and confirm the saved JSON can be imported by the current web contract.
- Enable airplane mode before launching: scanner and floorplan import should still load.
- Check a non-LiDAR iPhone as well as the phone you use for development.

## Structure

- `EventVision/ScannerController.swift`: camera, tracking lifecycle and corner input.
- `EventVision/ScanGeometry.swift`: geometry validation and shared JSON contract.
- `EventVision/EditorController.swift`: local WKWebView, bounded readiness retry, import acknowledgement and scan sharing.
- `EventVision/Web`: adapted v10.7.4 and pinned Three.js engine.
- `EventVisionTests`: geometry/contract XCTest cases.
- `scripts/check-editor.cjs`: browser smoke test of import and furniture interaction; requires Playwright and a Chromium executable.
- `BASELINE.txt`: original file identity and exact scope of the native HTML changes.
- `VALIDATION.md`: what was and was not executed.

The bridge passes the scan as a structured JavaScript argument, not executable string interpolation. Only the bundled editor file is allowed as a main-frame navigation. No camera/location/account server or telemetry was added.

## Apple references

- https://developer.apple.com/documentation/arkit/arscnview/raycastquery(from:allowing:alignment:)
- https://developer.apple.com/documentation/arkit/arconfiguration/issupported
- https://developer.apple.com/documentation/webkit/wkwebview/callasyncjavascript(_:arguments:in:in:completionhandler:)
