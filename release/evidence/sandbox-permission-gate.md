# Sandboxed Accessibility permission evidence

- Date: 2026-09-04 (Asia/Tokyo)
- Artifact: `.derived-sandbox-release/Build/Products/Release/ShortcutCoach.app`
- Bundle: `com.serp.shortcutcoach`
- Version: `1.0.0 (1)`
- Architectures: `arm64`, `x86_64`
- Local gate signature: Developer ID Application, team `847HR8U8D9`
- Signature verification: strict/deep pass
- Hardened runtime: present (`runtime` code-sign flag)
- Entitlements: only `com.apple.security.app-sandbox = true`
- Store icon: generated `AppIcon.icns` plus opaque 1024×1024 source

## Reproduction

1. Reset Accessibility for only `com.serp.shortcutcoach`.
2. Launch the exact sandboxed Release artifact.
3. Open Permissions and confirm Status is Required.
4. Choose Request Permission.
5. Observe that no system prompt or System Settings pane opens and Status remains Required.
6. Inspect unified logs for the app process.

Observed twice, including after the clean reset:

~~~text
ShortcutCoach[...] activating connection: mach=true ... name=com.apple.universalaccessAuthWarn
ShortcutCoach[...] failed to do a bootstrap look-up: xpc_error=[159: Unknown error: 159]
~~~

## Control

The Debug control used the same source, team, bundle ID, and request call but no App Sandbox entitlement. After a fresh Accessibility reset, its unified log connected to `com.apple.universalaccessAuthWarn` and did not emit the bootstrap failure. No Accessibility toggle was changed by automation.

## Conclusion

This test does not claim that every possible sandbox entitlement request is impossible. It proves that the public-API, sandboxed Release configuration currently specified for Shortcut Coach cannot complete its required clean Accessibility permission flow. Under issue #19's stop condition, App Store upload and submission are blocked. The release fallback is the hardened, unsandboxed Developer ID configuration under `release/developer-id/`.
