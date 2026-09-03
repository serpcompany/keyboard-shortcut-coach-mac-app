# Release publication

Every shipped version has an immutable Git tag and GitHub Release in `serpcompany/keyboard-shortcut-coach-mac-app`. Read [`release/release-lanes.md`](../../release/release-lanes.md) before choosing a lane.

## Tag names

- Full: `full-vMAJOR.MINOR.PATCH`
- App Store Lite: `lite-vMAJOR.MINOR.PATCH`

The tag points to the exact `main` commit used for the external release. Use annotated tags; the GitHub Release uses the same tag.

## Publication sequence

1. Finish lane-specific tests and distribution validation. Completion: every gate in the selected lane's release doc passes against one commit.
2. Merge that commit to `main`, fetch `origin/main`, and confirm local `HEAD` equals `origin/main`. Completion: the worktree is clean and both hashes match.
3. Finish the external lane:
   - Full: notarize and staple the public artifact before tagging.
   - Lite: record the processed App Store Connect build and wait until the version is approved for distribution before publishing the final GitHub Release.
4. Add the version and user-facing changes to `CHANGELOG.md`. Completion: the release version is no longer represented only by `Unreleased` notes.
5. Run `scripts/publish-github-release.sh` with `--dry-run`, inspect its exact tag/commit/artifact plan, then run it without `--dry-run`. Completion: the tag and GitHub Release both resolve to the shipped commit.
6. Verify with `git ls-remote --tags origin` and `gh release view TAG`. Completion: title, notes, commit, assets, and checksums match the external release.

## Examples

~~~sh
# Full release: attach the notarized archive and its generated checksum.
scripts/publish-github-release.sh \
  --lane full \
  --version 1.0.0 \
  --artifact dist/Shortcut-Coach-1.0.0.zip \
  --prerelease \
  --dry-run

# App Store Lite: GitHub is the public ledger; the Store distributes the binary.
scripts/publish-github-release.sh \
  --lane lite \
  --version 1.0.0 \
  --dry-run
~~~

## Guardrails

- Reserve the tag only after the exact external artifact/build is known.
- A failed GitHub Release creation leaves evidence in the pushed tag; repair that release instead of silently retagging another commit.
- Attach the notarized full artifact, never an unsigned or unstapled build.
- Use `--prerelease` for public test builds that are not yet the recommended general release.
- Do not attach a Mac App Store package for public installation. Record its App Store version/build identifiers in the release notes.
- Treat GitHub Releases as public. Keep certificates, profiles, API keys, private logs, reviewer contact details, and Apple correspondence out of assets and notes.
