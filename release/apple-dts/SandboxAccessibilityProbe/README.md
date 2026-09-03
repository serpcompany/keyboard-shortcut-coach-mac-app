# Sandbox Accessibility Probe

Focused Apple DTS sample for the failure documented in [`../request.md`](../request.md).

The app contains one public Accessibility call, one status refresh, App Sandbox, and no Shortcut Coach product code.

~~~sh
cd release/apple-dts/SandboxAccessibilityProbe
xcodegen generate
xcodebuild \
  -project SandboxAccessibilityProbe.xcodeproj \
  -scheme SandboxAccessibilityProbe \
  -configuration Release \
  -derivedDataPath .derived \
  build
~~~

Reproduction:

1. Run `tccutil reset Accessibility com.serp.shortcutcoach.dtsprobe`.
2. Launch the signed app.
3. Choose **Request Accessibility Permission**.
4. Compare the prompt, trust status, and unified log with an otherwise identical build whose App Sandbox entitlement is removed.
