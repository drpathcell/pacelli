fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios sync_signing

```sh
[bundle exec] fastlane ios sync_signing
```

Sync certificates and provisioning profiles (read-only by default)

### ios build

```sh
[bundle exec] fastlane ios build
```

Build a signed iOS IPA (no upload)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build + upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit latest TestFlight build to App Store review

### ios regenerate_signing

```sh
[bundle exec] fastlane ios regenerate_signing
```

Regenerate certs/profiles (CI: set readonly=false + MATCH_GIT_URL writable)

----


## Android

### android build

```sh
[bundle exec] fastlane android build
```

Build a signed Android AAB

### android beta

```sh
[bundle exec] fastlane android beta
```

Build + upload to Play Store internal track

### android release

```sh
[bundle exec] fastlane android release
```

Promote internal build to production

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
