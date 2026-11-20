# Contributing to tsudev-ui-flutter (`tsudev_ui`)

_Tiếng Việt: mọi đóng góp đều được chào đón. Bạn có thể viết issue và pull request bằng tiếng Việt hoặc tiếng Anh._

`tsudev_ui` is the shared Flutter package of the TsuDEV apps: Pro / Supporter badges, the Pro notices, and the
client side of TsuDEV entitlements (ES256 JWS + JWKS verification, DPoP, installation id). See [README.md](README.md)
for what each component does and [docs/adr/](docs/adr/) for the design decisions.

## Reporting bugs and requesting features

- **Bug**: open an issue with the *Bug report* form: <https://github.com/tsudev-org/tsudev-ui-flutter/issues/new/choose>.
  Include the package version (git tag), Flutter version, platform and the steps to reproduce.
- **Feature**: use the *Feature request* form. Behaviour that is fixed by the TsuDEV product policy (texts, timings of
  the Pro notices) is changed in the standards first, then here.
- **Security vulnerability**: never in a public issue - see [SECURITY.md](SECURITY.md) (private vulnerability
  reporting on the Security tab).

## Getting the source, building and testing

The package is pure Dart/Flutter; nothing is compiled ahead of the app that depends on it.

```bash
git clone https://github.com/tsudev-org/tsudev-ui-flutter.git
cd tsudev-ui-flutter
flutter pub get
dart format --output=none --set-exit-if-changed lib test   # formatting
flutter analyze --fatal-infos                               # static analysis, every lint is an error
flutter test                                                # unit, widget, golden and fuzz tests
```

Golden images only match on Linux with the Flutter version pinned in CI (`FLUTTER_VERSION` in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml)). The fuzz tests use a fixed seed; run them with another seed
using `flutter test --dart-define=FUZZ_SEED=<number> test/entitlement_verifier_fuzz_test.dart`.

## Pull request requirements

Every change goes through a pull request into `main` (direct pushes are blocked) and is squash-merged.

1. **One change per pull request**, with a description of what and why. Commit messages follow
   [Conventional Commits](https://www.conventionalcommits.org/) (`feat: ...`, `fix: ...`, `docs: ...`).
2. **Tests**: every change in behaviour comes with tests in the same pull request. A bug fix comes with a regression
   test that fails without the fix. Changes to the entitlement verifier, DPoP or the installation id also need a
   negative test (tampered or malformed input is rejected).
3. **CI must be green**: formatting, `flutter analyze --fatal-infos` (strict-casts, strict-inference,
   strict-raw-types), all tests, gitleaks, and the TsuDEV standards check.
4. **Cryptography**: use the published algorithms through `pointycastle` only (ECDSA P-256 / SHA-256); never implement
   a primitive yourself, never accept keys from the token header, never log tokens or the installation id.
5. **Changelog**: user-visible changes get an entry in [CHANGELOG.md](CHANGELOG.md) (Keep a Changelog, SemVer).
6. Dependencies and GitHub Actions are pinned (pub lock ranges, Actions by commit SHA) and updated by Dependabot.

## Releases

Versions follow [Semantic Versioning](https://semver.org/). A release is an annotated tag `vX.Y.Z` on `main` whose
notes are the matching section of [CHANGELOG.md](CHANGELOG.md); apps pin the tag in their `pubspec.yaml`.

## License

By contributing you agree that your work is licensed under the [GNU AGPL-3.0-only](LICENSE), like the rest of the
project. Everyone taking part follows the
[TsuDEV Code of Conduct](https://github.com/tsudev-org/.github/blob/main/CODE_OF_CONDUCT.md).
