# Brand separation and identity migration audit

Audit issue: [#1](https://github.com/serpcompany/keylume-mac-hotkey-app-clone/issues/1)  
Audit date: 2026-08-15  
Scope: audit only. No product rename, asset replacement, behavior change, Goal 1 evidence edit, or Goal 2 implementation was performed.

`brand-swap-manifest.json` is the machine-readable source of truth. Its 41 rows use the same stable IDs as this inventory. Related literals are grouped only when they share one migration boundary and one verification method; the row's source locations define the full group.

## Result

The candidate is not ready to ship as an independently branded product. It has no detected runtime or packaged dependency on Keylume-operated services, accounts, credentials, signing material, or update infrastructure, but the working/reference name remains across product copy, code/package identifiers, persistence, evidence, licensing format, and repository metadata. Its exact parity-oriented colors, typography hierarchy, geometry, shapes, and timing also need an original approved design system.

No custom logo, app icon, artwork, font, sound, animation asset, dataset, model, external Swift package, vendored library, support service, authentication service, crash reporter, telemetry client, sync service, or remote licensing client was found. The absence of an app icon/logo is itself a brand deliverable, not proof that the identity work is complete.

The only network-capable code path is the optional update checker. It reads `KEYLUME_CLONE_UPDATE_FEED`, performs a `URLSession` request to that supplied URL, decodes `version` and `downloadURL`, and can open the returned download URL. No feed is configured by default and no candidate-owned operator/domain/update authenticity policy exists yet. A bounded observation of running installed PID 43559 showed no open TCP or UDP sockets. Full destination proof is blocked until the owner supplies a non-secret staging feed and an approved destination list.

### Counts

| Disposition | Count |
| --- | ---: |
| `replace` | 17 |
| `redesign` | 5 |
| `remove` | 1 |
| `owner-decision` | 13 |
| `keep-system` | 5 |
| **Total** | **41** |

| Category | Count |
| --- | ---: |
| copy | 7 |
| data-persistence | 4 |
| design-system | 3 |
| distribution | 1 |
| legal-provenance | 3 |
| os-integration | 6 |
| product-identity | 4 |
| services-infrastructure | 6 |
| third-party-assets | 1 |
| third-party-dependencies | 2 |
| visual-assets | 4 |

## Inventory

| Stable ID | Category | Observed surface | Provenance and risk | Disposition | Status |
| --- | --- | --- | --- | --- | --- |
| `identity.product-name` | product-identity | `Keylume`, `Keylume Clone`, `KeylumeClone`, and `KEYLUME` across UI, code, package, tests, docs, scripts, binary, and filenames | Reference name plus clone qualifier; no approved final identity | `replace` | pending owner name |
| `identity-company-namespace` | product-identity | `co.serp` and `serpcompany` | Candidate/operator namespace; legal and customer-facing ownership unconfirmed | `owner-decision` | pending owner/entity decision |
| `identity-repository-name` | product-identity | `keylume-mac-hotkey-app-clone` | Working research/clone repository identity | `replace` | pending repository/redirect decision |
| `identity-version-build` | product-identity | `1.1.2 (7)` | Matches frozen reference baseline | `owner-decision` | pending independent version policy |
| `identity-copyright-credits` | legal-provenance | “Independent clean-room implementation.” and “Made with ♥ for macOS” | Candidate placeholders; no legal holder/year/assignment record | `owner-decision` | pending legal owner |
| `copy-menu-window-alerts` | copy | Status menu, window titles, picker text, update alerts, errors, and quit copy | Candidate-authored, reference-workflow-derived, with working name residue | `replace` | copy deck needed |
| `copy-onboarding` | copy | Welcome, Accessibility, How It Works, feature and 14-day commercial claims, navigation | Closely follows reference surface and business message | `replace` | product/legal copy decision needed |
| `copy-settings-about-license` | copy | General/Coaching/About, documents, trial/license states and errors | Working identity and reference terminology remain | `replace` | settings/license copy decision needed |
| `copy-overlay-coaching` | copy | Search, empty states, shortcut count, close help, toast, permanent-dismiss text and AX label | Modeled on reference interaction language | `replace` | original terminology needed |
| `copy-analytics` | copy | Progress, mastered/learn-next, metric and empty-state language | Reference information architecture and coaching voice | `replace` | metric/voice approval needed |
| `copy-packaged-documents` | copy | `README.md` and `privacy.md`, copied into the app | Candidate-authored but clone-branded and incomplete for public product | `replace` | branded/legal documents needed |
| `copy-goal2-plan` | copy | Keylume Home/management language and old scheme in plan only | Planning artifact; no Goal 2 implementation occurred | `replace` | update only after identity approval |
| `visual-app-icon-logo` | visual-assets | No app icon, asset catalog, or logo | Missing owned identity asset; no reference artwork was shipped | `redesign` | commission original assets |
| `visual-menu-bar-icon` | visual-assets | Apple `keyboard` SF Symbol | Safe system primitive, but current choice is not an owned mark | `owner-decision` | choose original template icon or approve symbol |
| `visual-system-symbols` | third-party-assets | Apple SF Symbols throughout | Platform-owned API-rendered symbols; no copied files | `keep-system` | retain subject to approved design/platform terms |
| `visual-colors-materials` | design-system | Semantic Apple colors/materials plus literal opacity values | Selected for reference parity, not an approved future palette | `redesign` | create original semantic tokens |
| `visual-typography` | design-system | Apple system styles, rounded keycaps, monospaced digits | System fonts arranged to match reference hierarchy | `redesign` | approve original type scale/font policy |
| `visual-geometry-shapes` | design-system | Exact window sizes, padding, spacing, cards, keycaps, radii, toast position | Deliberate observable-reference parity | `redesign` | create original layout/component tokens |
| `visual-motion-animation-sound` | visual-assets | System presentation and 300ms/1.5s/4s timings; no custom media | Timing partly parity-derived; no copied sounds/animation files | `redesign` | approve original motion/sound direction |
| `evidence-reference-captures` | legal-provenance | 18 reference PNGs, 12 reference AX text captures, 5 additional onboarding screenshots | Clean-room evidence may expose reference-owned expression; never packaged | `owner-decision` | legal/public-repository retention review |
| `evidence-candidate-captures` | visual-assets | 18 candidate PNGs plus candidate AX captures | Pre-rebrand identity and parity visuals; never packaged | `replace` | retain/archive old proof and create post-rebrand proof |
| `identifier-bundle-id` | os-integration | `co.serp.KeylumeClone` | Candidate placeholder; drives defaults, TCC, signing, URL registration and login item | `replace` | final ID and migration strategy needed |
| `identifier-product-executable-module` | os-integration | Package/product/target/executable/app/process/source/test names | Working clone identity embedded in symbols and filenames | `replace` | approve internal/external naming |
| `identifier-url-scheme` | os-integration | `keylumeclone://settings` and `keylumeclone://analytics`; URL name `co.serp.KeylumeClone` | Candidate placeholder, distinct from reference `keylume://` | `replace` | final scheme/compatibility policy needed |
| `identifier-preferences-domain-keys` | data-persistence | Bundle defaults domain and 16 enumerated preference/trial/license keys | Candidate-local; identity-sensitive domain and license keys | `replace` | approve migration/rollback policy |
| `identifier-application-support` | data-persistence | `~/Library/Application Support/KeylumeClone/usage.json` | Working-name path containing controlled/user usage data | `replace` | approve private-data migration/retention |
| `identifier-license-format-storage` | data-persistence | `KEYLUME-…` key format; plaintext UserDefaults local validation | Independent behavior but reference name remains; no reference service | `replace` | choose commercial and secure-storage model |
| `identifier-environment-update-feed` | services-infrastructure | `KEYLUME_CLONE_UPDATE_FEED` | Candidate config boundary; no value or secret committed | `replace` | choose production configuration boundary |
| `os-accessibility-tcc` | os-integration | Apple AX/TCC/EventTap and System Settings path | Public platform mechanism; record binds to final bundle/signature, and permission copy is branded | `keep-system` | retain API, replace copy, fully retest |
| `os-login-item` | os-integration | `SMAppService.mainApp` and `launchAtLogin` | Public platform mechanism; registration is identity-sensitive | `keep-system` | migration behavior needed |
| `os-dynamic-external-identifiers` | data-persistence | Other apps' names, bundle IDs, icons, menu paths and shortcuts | User/system/application-provided data, not reference branding; privacy-sensitive | `keep-system` | approve privacy/retention/icon-display policy |
| `os-unused-identity-surfaces` | os-integration | No UTI, app group, keychain item/label, helper, custom notification ID, pasteboard type, AX ID, user agent, installer metadata, or app sandbox entitlement | Confirmed current absence | `owner-decision` | confirm omissions match distribution/product plan |
| `service-reference-update-endpoint` | services-infrastructure | `https://keylume.app/appcast.xml` only in frozen scope evidence | Reference-owned service; no production/binary dependency | `remove` | exclude from production; archive evidence by policy |
| `service-update-feed-download` | services-infrastructure | Optional arbitrary JSON feed and returned download URL | No selected owner/domain/signing/authenticity/security policy | `owner-decision` | choose owned infrastructure or remove feature |
| `service-network-observation` | services-infrastructure | No sockets observed; update destination path not exercisable without a feed | Point-in-time evidence, not full packet proof | `owner-decision` | blocked on non-secret staging feed/allowlist |
| `service-absent-clients` | services-infrastructure | No remote analytics/crash/telemetry/auth/account/sync/model/license/support/privacy/legal client | Confirmed current absence; local analytics only | `owner-decision` | approve vendor/service policy before adding any |
| `infrastructure-accounts-secrets-credentials` | services-infrastructure | No committed service/reference credentials; installed candidate uses Apple Development team `847HR8U8D9`; fresh build is ad-hoc | Candidate signing boundary; secret values were not sought or printed | `owner-decision` | production accounts, custody and rotation needed |
| `distribution-signing-notarization` | distribution | Universal package; ad-hoc by default; installed dev-signed; no notarization/installer/release CI/update signing | Development packaging, not a production-owned channel | `owner-decision` | choose channel, team, signing, notarization and release owner |
| `dependencies-apple-frameworks` | third-party-dependencies | Apple SDK/runtime only; no Swift package dependency | Platform dependencies, no vendored binaries | `keep-system` | verify platform terms/minimum OS |
| `dependencies-assets-models-datasets` | third-party-dependencies | No custom assets/fonts/sounds/models/datasets/license/NOTICE/acknowledgements; resources are README/privacy only | Confirmed absence | `owner-decision` | require provenance ledger for all additions |
| `legal-support-privacy-terms` | legal-provenance | No owner/contact/public policies/EULA/trademark statement/attributions/repository license | Incomplete public-product legal/support surface | `owner-decision` | legal/product package required |

## Highest-risk dependencies and migration boundaries

1. The product name is structural, not cosmetic. It appears in the module, executable, package, bundle paths, binary symbols, UI, copy, license prefix, defaults/Application Support identity, repository, tests, scripts, and evidence.
2. Bundle/signing changes will create a new macOS identity for Accessibility/TCC, login items, LaunchServices URL handling, preferences, Finder metadata, and potentially update eligibility. These require installed-artifact migration tests, not only string replacement.
3. The local `KEYLUME-…` entitlement format both retains reference identity and stores the license in UserDefaults. A commercial and secure-storage decision must precede implementation.
4. Update behavior accepts an operator-supplied feed and opens its returned download URL without an established candidate-owned domain, update-signing/authenticity policy, or production account owner.
5. The exact parity design treatment remains visually derivative even where primitives are Apple-owned. Brand work must create original color, typography, spacing, shape, icon, copy, and motion systems rather than simply substitute a name.
6. Reference screenshots/AX captures are not shipped, but they are tracked in a public remote. Their clean-room/legal retention policy needs owner review.

## Owner-decision queue

1. Final trademark-cleared product name, logo, app icon, menu-bar icon, legal entity, customer-facing company name, reverse-DNS namespace, URL scheme, repository slug, and version line.
2. Original design system: semantic light/dark colors, typography scale/font policy, spacing, radii, geometry, component treatment, motion/timing, illustration, and optional sound direction.
3. Original copy deck and terminology for onboarding, permission prompts, menus, overlay/coaching, settings, analytics, alerts/errors, trial/license claims, About, README, and privacy.
4. Commercial entitlement model: trial/purchase promises, key/account format, issuance/revocation, secure storage, migration, support, and whether remote licensing exists.
5. Update and distribution model: candidate-owned domains/accounts, staging feed, manifest/download authenticity, signing/notarization, Developer ID/App Store team, CI secrets, certificate/update-key custody and rotation.
6. Persistence migration: defaults domain and 16 keys, Application Support usage records, privacy retention/reset/uninstall behavior, existing login item, URL handlers, Accessibility/TCC reauthorization, and rollback.
7. Legal/provenance package: trademark clearance, copyright holder/year, contributor/assignment records, repository license, EULA/terms, privacy notice, support contact, Apple/third-party attributions, commissioned-asset assignments, and asset/dependency ledger.
8. Evidence policy: whether reference and pre-rebrand candidate screenshots/AX captures may remain public, must be restricted, or should be archived elsewhere without weakening the frozen clean-room record.
9. Service policy: whether analytics/crash/telemetry/auth/sync/support/cloud/model services remain absent; if added, approve vendor, account owner, licenses/DPAs, collected data, retention/deletion, and destination allowlist first.

## Independence evidence

- Production source/config and the fresh packaged executable contain no `keylume.app` URL or reference app bundle ID `app.keylume.Keylume`. The known reference appcast appears only in frozen `scope.md` evidence.
- The candidate bundle ID `co.serp.KeylumeClone`, scheme `keylumeclone`, local license implementation, and optional update feed are separate from the reference identities. They still require replacement because they contain the working clone name or lack an owner-approved production boundary.
- No reference Keychain data was read. The candidate itself has no Keychain API or keychain label; its local candidate license lives in UserDefaults.
- No service tokens, API keys, update keys, cloud resources, reference accounts, private reference credentials, or hard-coded candidate service destinations were found. No secret values were printed or recorded.
- The fresh package contains exactly five files: `Info.plist`, the universal executable, `README.md`, `privacy.md`, and `_CodeSignature/CodeResources`.
- `otool -L` shows Apple system frameworks/libraries only on both architectures. `Package.swift` has no external dependencies and there is no `Package.resolved`.
- The fresh package is valid ad-hoc code signed; the installed accepted candidate is Apple Development signed by team `847HR8U8D9`. Neither state is an approved production identity.
- Bounded `lsof` observation of the running installed candidate returned no TCP/UDP sockets. The optional update path remains runtime-unproven because no non-secret configured feed was available.

## Validation evidence

Commands completed successfully unless a limitation is stated:

```text
swift test
  11 Swift Testing tests passed

zsh scripts/package_app.sh
  universal x86_64/arm64 release app built
  Info.plist lint passed
  strict deep code-sign verification passed

find .build/release/KeylumeClone.app -type f
plutil -p .build/release/KeylumeClone.app/Contents/Info.plist
codesign -dvvv .build/release/KeylumeClone.app
codesign -d --entitlements :- .build/release/KeylumeClone.app
otool -L .build/release/KeylumeClone.app/Contents/MacOS/KeylumeClone
strings -a .build/release/KeylumeClone.app/Contents/MacOS/KeylumeClone | rg ...
  package metadata, resources, signing, empty entitlements, linked libraries, and embedded identity strings inspected

find /Applications/Keylume\ Clone.app -type f
plutil -p /Applications/Keylume\ Clone.app/Contents/Info.plist
codesign -dvvv /Applications/Keylume\ Clone.app
  installed artifact metadata/signing inspected read-only

lsof -nP -a -p 43559 -i
  no open sockets at observation time; full update destination capture blocked by missing non-secret feed configuration

jq -e . docs/app-replica/brand-swap-manifest.json
  JSON valid
```

The frozen Goal 1 files retained their pre-audit SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `docs/app-replica/completion-manifest.json` | `f9b56c850d3d9e285e62ed37c1973d1ea9a2bc95836263439fcbbc1ed74cc36c` |
| `docs/app-replica/scope.md` | `14fc4890dcdbfd329098270f84e6d39a956c7e73aaad182105a3f464761dff08` |
| `docs/app-replica/parity-ledger.md` | `5fbe6541300d2df390508680b2c444e257dbeefa70e2d83a3f4f083ab6083712` |
| `docs/app-replica/verification.md` | `0afebfd780da98ce265fb7995a55c8a1ca23767e1b454e2c5fe2bcde5a1ace44` |

## Implementation gate

Do not begin the rebrand until the owner resolves the queue above and creates a separate implementation issue. After implementation, rerun the full installed Goal 1 workflow, persistence migration, denied/granted Accessibility paths, login-item registration/removal, URL routing, update network/destination tests, signing/notarization, fresh install/update/uninstall, binary/reference-name scans, light/dark visual/accessibility review, and post-rebrand evidence capture.
