<!--
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Building locally with your own signing identity

The Xcode project does not contain a team identifier, a bundle identifier or an entitlements path for
signing. They live in configuration files instead, so that no developer's account details are part of
the repository:

| File | Tracked | Purpose |
| --- | --- | --- |
| `iOCNotes.xcconfig` | yes | Shared defaults for every build. Sets the default entitlements and bundle identifier. |
| `Local.xcconfig` | **no** | Your personal overrides. Optional; included only when it exists. |
| `Brand/iOCNotes.entitlements` | yes | Entitlements of the shipped app, including the `group.com.nextcloud.apps` app group. |
| `Local.entitlements` | **no** | Entitlements for a build that cannot use that app group. Optional. |

`iOCNotes.xcconfig` ends with

```
#include? "Local.xcconfig"
```

The `?` makes the include optional: a fresh checkout without `Local.xcconfig` builds with the shared
defaults exactly as before.

## Setting it up

1. Create `Local.xcconfig` in the repository root:

   ```
   DEVELOPMENT_TEAM = <YOUR_TEAM_ID>
   CODE_SIGN_STYLE = Automatic
   PRODUCT_BUNDLE_IDENTIFIER = <your.bundle.id>
   CODE_SIGN_ENTITLEMENTS = Local.entitlements
   ```

2. Create `Local.entitlements` in the repository root, if your team cannot register the app group
   `group.com.nextcloud.apps` (this is always the case for a free "Personal Team"):

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>com.apple.security.app-sandbox</key>
       <true/>
       <key>com.apple.security.network.client</key>
       <true/>
       <key>keychain-access-groups</key>
       <array/>
   </dict>
   </plist>
   ```

   Without the app group, the app cannot read account information shared by the Nextcloud iOS app
   (`NKShareAccounts`). Everything else, including synchronization, works.

3. Keep both files out of version control. They are already excluded locally through
   `.git/info/exclude`; add the same two names to your global ignore list if you want the protection
   in every clone.

## Verifying the effective settings

```
xcodebuild -project iOCNotes.xcodeproj -scheme iOCNotes -showBuildSettings -sdk iphoneos \
  | grep -E "DEVELOPMENT_TEAM|CODE_SIGN_ENTITLEMENTS|PRODUCT_BUNDLE_IDENTIFIER"
```

A device build then signs with your own profile:

```
xcodebuild build -project iOCNotes.xcodeproj -scheme iOCNotes \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates
```

## Using the app group

With a paid team that can register `group.com.nextcloud.apps`, point
`CODE_SIGN_ENTITLEMENTS` at the tracked file again:

```
CODE_SIGN_ENTITLEMENTS = Brand/iOCNotes.entitlements
```

No other change is required; the entitlements of the shipped app are unchanged.

## What must never be committed

`Local.xcconfig` and `Local.entitlements` contain a team identifier, a bundle identifier and possibly a
provisioning profile name. They are untracked by design. The project file itself contains no account
details, which is why CI can build it without any of these files:

```
xcodebuild build -project iOCNotes.xcodeproj -scheme iOCNotes \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
