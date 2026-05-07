# OpenASO Release Setup

OpenASO releases are Developer ID signed, notarized, distributed as a DMG, and published through GitHub Releases plus a Cloudflare R2-hosted Sparkle appcast.

## One-time Sparkle key setup

After Xcode resolves the Sparkle package, find the tools under DerivedData:

```sh
xcodebuild -resolvePackageDependencies -project OpenASO.xcodeproj -scheme OpenASO -derivedDataPath Build
find Build/SourcePackages/artifacts -path '*/Sparkle/bin/generate_keys' -print
```

Generate the EdDSA key once:

```sh
Build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
Build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private_key
base64 -i sparkle_private_key | pbcopy
```

Store the copied value in GitHub as `SPARKLE_PRIVATE_KEY_BASE64`. The release workflow imports this key with Sparkle's `generate_keys -f`, derives the matching public key, and injects that public key into the release build as `SUPublicEDKey`.

## Required GitHub secrets

- `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`
- `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`
- `APPLE_TEAM_ID`
- `APPSTORE_CONNECT_API_KEY_ID`
- `APPSTORE_CONNECT_API_ISSUER_ID`
- `APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64`
- `SPARKLE_PRIVATE_KEY_BASE64`
- `POSTHOG_PROJECT_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_R2_ACCESS_KEY_ID`
- `CLOUDFLARE_R2_SECRET_ACCESS_KEY`

## Required GitHub variables

- `CLOUDFLARE_R2_BUCKET`
- `POSTHOG_HOST` if not using the PostHog default host

Export the Developer ID Application certificate from Keychain as a `.p12`, then store its base64 form:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

The App Store Connect API private key should be stored as the base64 form of the `.p8` file:

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

Connect the R2 bucket to `releases.openaso.thirdtechapps.com` as a public custom domain. The workflow syncs prior DMGs from `s3://$CLOUDFLARE_R2_BUCKET/releases/` before generating the appcast so Sparkle can continue to see the full release archive.

The appcast is published at:

```text
https://releases.openaso.thirdtechapps.com/appcast.xml
```

Release DMGs and Sparkle release-note files are published under:

```text
https://releases.openaso.thirdtechapps.com/releases/
```

A stable latest-DMG URL is also published on every release:

```text
https://releases.openaso.thirdtechapps.com/downloads/OpenASO.dmg
```

The versioned DMGs are immutable and safe for Sparkle history. The latest-DMG URL is overwritten by each release and uses a short cache lifetime, so the landing page can link to one URL without needing to know the current version.

## Release flow

Run the `Release macOS App` workflow manually from GitHub Actions. Provide:

- `release_title`: human-readable title
- `changelog_body`: Markdown release notes

The workflow reads `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from the Xcode project, runs tests, updates `CHANGELOG.md`, creates a `v{version}` tag, builds the signed app, notarizes/staples the app and DMG, regenerates `appcast.xml`, uploads the appcast and release artifacts to Cloudflare R2, and creates the GitHub Release.
