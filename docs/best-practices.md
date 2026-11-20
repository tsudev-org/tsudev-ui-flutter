# OpenSSF Best Practices - tsudev_ui

Hồ sơ [16948](https://www.bestpractices.dev/projects/16948) - mức **passing** (100%, nộp 20/11/2026) trên [bestpractices.dev](https://www.bestpractices.dev/). Nguồn sự thật: [`best-practices.json`](best-practices.json) (công cụ `bp.cjs` điền biểu mẫu từ tệp này). Mỗi câu `Met` có bằng chứng trên `main`; sửa repo thì cập nhật cả hai tệp.

Tổng: 63 Met, 3 N/A, 1 Unmet.

| Tiêu chí | Trạng thái | Bằng chứng (English, as submitted) |
| --- | --- | --- |
| `description_good` | Met | README.md describes what the package does (shared Flutter package of the TsuDEV apps: Pro/Supporter badges, Pro notices, ES256 entitlement JWS verification with JWKS, DPoP and installation id), with an English summary: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/README.md |
| `interact` | Met | README.md and CONTRIBUTING.md explain how to obtain the source, build and test it, report bugs, request features (issue forms) and contribute: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CONTRIBUTING.md |
| `contribution` | Met | CONTRIBUTING.md explains the contribution process: pull requests into main (direct pushes are blocked by a ruleset), reviewed and squash-merged: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CONTRIBUTING.md |
| `contribution_requirements` | Met | CONTRIBUTING.md lists the requirements: Conventional Commits, tests with every behaviour change (regression and negative tests), green CI (format, strict analyzer, tests, gitleaks), pointycastle-only cryptography, CHANGELOG entry: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CONTRIBUTING.md |
| `floss_license` | Met | GNU AGPL-3.0-only: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/LICENSE |
| `floss_license_osi` | Met | AGPL-3.0 is OSI approved; GitHub detects the license as AGPL-3.0. |
| `license_location` | Met | The license is in the standard location LICENSE at the repository root: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/LICENSE |
| `documentation_basics` | Met | README.md (components, installation, usage examples, development), CONTRIBUTING.md (build and test), SECURITY.md (security guarantees), CHANGELOG.md and the design decision docs/adr/0001: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/README.md |
| `documentation_interface` | Met | The public API is documented: README.md has a usage section for every component (badges, Pro notices, entitlements, DPoP, installation id) and every public class and method in lib/ has dartdoc comments: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/lib/tsudev_ui.dart |
| `sites_https` | Met | The project lives on GitHub (https://github.com/tsudev-org/tsudev-ui-flutter), served over HTTPS only; the TsuDEV endpoints the package calls (https://tsudev.com) are HTTPS only with HSTS, and the package refuses non-https endpoints. |
| `discussion` | Met | GitHub Issues and pull requests are public, searchable, URL-addressable and open to anyone with a GitHub account: https://github.com/tsudev-org/tsudev-ui-flutter/issues |
| `english` | Met | README.md and SECURITY.md have English summaries, CONTRIBUTING.md is in English and issues are accepted in English or Vietnamese: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CONTRIBUTING.md |
| `maintained` | Met | Actively maintained: two releases (v0.1.0, v0.2.0) and several merged pull requests in November 2026: https://github.com/tsudev-org/tsudev-ui-flutter/pulls?q=is%3Apr+is%3Amerged |
| `repo_public` | Met | Public git repository on GitHub: https://github.com/tsudev-org/tsudev-ui-flutter |
| `repo_track` | Met | git records who changed what and when; every change is a pull request with a description: https://github.com/tsudev-org/tsudev-ui-flutter/commits/main |
| `repo_interim` | Met | All work, including work in progress, is pushed to branches and merged into main through pull requests in the public repository: https://github.com/tsudev-org/tsudev-ui-flutter/pulls?q=is%3Apr |
| `repo_distributed` | Met | git (a distributed version control system) on GitHub. |
| `version_unique` | Met | Each release has a unique version identifier (v0.1.0, v0.2.0), also in pubspec.yaml: https://github.com/tsudev-org/tsudev-ui-flutter/tags |
| `version_semver` | Met | Semantic Versioning (MAJOR.MINOR.PATCH), stated in CHANGELOG.md and CONTRIBUTING.md: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CHANGELOG.md |
| `version_tags` | Met | Each release is an annotated git tag vX.Y.Z on main; apps pin the tag in their pubspec.yaml: https://github.com/tsudev-org/tsudev-ui-flutter/tags |
| `release_notes` | Met | CHANGELOG.md (Keep a Changelog) has human-readable release notes for every version, listing what was added and changed: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CHANGELOG.md |
| `release_notes_vulns` | N/A | No vulnerability with a CVE or similar public identifier has been fixed in this project. SECURITY.md commits to naming such fixes in CHANGELOG.md. |
| `report_process` | Met | Bug reports go to GitHub Issues using the bug report form (organization default forms): https://github.com/tsudev-org/tsudev-ui-flutter/issues/new/choose |
| `report_tracker` | Met | GitHub Issues with bug report and feature request forms: https://github.com/tsudev-org/tsudev-ui-flutter/issues |
| `report_responses` | Met | No external bug report has been filed so far (young project); the maintainer reads every issue and acknowledges reports within days. |
| `enhancement_responses` | Met | No external enhancement request has been filed so far; the feature request form routes them to the maintainer, who answers each one. |
| `report_archive` | Met | GitHub Issues are public and searchable: https://github.com/tsudev-org/tsudev-ui-flutter/issues?q=is%3Aissue |
| `vulnerability_report_process` | Met | SECURITY.md describes how to report vulnerabilities (English summary included): https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/SECURITY.md |
| `vulnerability_report_private` | Met | GitHub private vulnerability reporting is enabled: https://github.com/tsudev-org/tsudev-ui-flutter/security/advisories/new |
| `vulnerability_report_response` | Met | No vulnerability report was received in the last 6 months. SECURITY.md commits to a reply within 7 days and a fix for serious issues within 30 days. |
| `build` | Met | Standard Dart/Flutter tooling: the package needs no separate build step; flutter pub get resolves it and apps compile it with flutter build. CI runs the same commands: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/.github/workflows/ci.yml |
| `build_common_tools` | Met | Standard tools: Flutter and Dart (pub, dart format, flutter analyze, flutter test). |
| `build_floss_tools` | Met | Flutter, Dart and all dependencies (http, pointycastle, flutter_lints) are FLOSS. |
| `test` | Met | Automated test suite (flutter test, 125 tests): unit tests for the JWS verifier, JWKS, DPoP, repository and installation id, widget tests at narrow and wide sizes, light/dark golden tests and fuzz tests: https://github.com/tsudev-org/tsudev-ui-flutter/tree/main/test |
| `test_invocation` | Met | Standard invocation: flutter test (documented in README.md and CONTRIBUTING.md): https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CONTRIBUTING.md |
| `test_most` | Met | Tests cover every public component: header/signature/claim rejection cases of the verifier (alg confusion, embedded jwk, crit, tampered payload, bad signatures, expiry, lifetime), JWK curve checks, DPoP against independently computed vectors, policy timing of the Pro notices and their exact texts: https://github.com/tsudev-org/tsudev-ui-flutter/tree/main/test |
| `test_continuous_integration` | Met | GitHub Actions runs formatting, the strict analyzer and the full test suite with coverage on every pull request and push to main: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/.github/workflows/ci.yml |
| `test_policy` | Met | CONTRIBUTING.md: every change in behaviour comes with tests in the same pull request; a bug fix comes with a regression test; security-relevant changes need a negative test: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CONTRIBUTING.md |
| `tests_are_added` | Met | Recent changes add tests with the code, e.g. #1 (ProRenewal, jwsForServer and DPoP with their tests) and the entitlement verifier fuzz tests: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/test/entitlement_verifier_fuzz_test.dart |
| `tests_documented_added` | Met | The test requirement is written in CONTRIBUTING.md (Pull request requirements, point 2): https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/CONTRIBUTING.md |
| `warnings` | Met | Dart analyzer with flutter_lints plus strict-casts, strict-inference, strict-raw-types and extra rules (avoid_dynamic_calls, unawaited_futures): https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/analysis_options.yaml |
| `warnings_fixed` | Met | CI runs flutter analyze --fatal-infos, so every warning (even info level) fails the build and is fixed before merge: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/.github/workflows/ci.yml |
| `warnings_strict` | Met | Analyzer strict modes are enabled and --fatal-infos treats even informational lints as errors. |
| `know_secure_design` | Met | The maintainer documented the security design: trust boundary (client result only shows/hides UI, servers verify), key selection only from the discovered JWKS, no keys from token headers, fail-closed to the free tier: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/SECURITY.md (design: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/docs/adr/0001-thu-vien-dung-chung-quyen-loi-huy-hieu.md) |
| `know_common_errors` | Met | SECURITY.md and the tests address the common JWT/JWS errors and their mitigations: alg confusion and alg none, embedded jwk/jku/x5u/x5c keys, crit, invalid curve points, missing exp/aud/iss checks, over-long lifetimes, logging of tokens: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/test/entitlement_verifier_test.dart |
| `crypto_published` | Met | Only published algorithms: ECDSA P-256 with SHA-256 (ES256, RFC 7518), SHA-256 JWK thumbprints (RFC 7638) and DPoP (RFC 9449). |
| `crypto_call` | Met | No primitives are implemented in the project: ECDSA and SHA-256 come from the pointycastle library (signing uses RFC 6979 deterministic nonces); CONTRIBUTING.md forbids home-made primitives: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/pubspec.yaml |
| `crypto_floss` | Met | pointycastle (MIT) and the Dart SDK are FLOSS. |
| `crypto_keylength` | Met | ECDSA P-256 (128-bit security level, meets NIST minimums through 2030 and beyond); installation ids and DPoP jti values are 128 bits of CSPRNG output. |
| `crypto_working` | Met | No broken or weak algorithms (MD5, SHA-1, DES, RC4, ECB) are used anywhere; the verifier accepts only ES256. |
| `crypto_weaknesses` | Met | No security mechanism depends on an algorithm with known serious weaknesses; alg none/HS256 are rejected. |
| `crypto_pfs` | Met | The package only talks to https endpoints (non-https endpoints are refused) using the platform TLS stack, which negotiates TLS 1.3 (always ephemeral ECDHE, so perfect forward secrecy) with the TsuDEV servers by default (measured 2026-11-20: TLSv1.3 TLS_AES_256_GCM_SHA384). The Cloudflare edge still accepts legacy non-PFS TLS 1.2 cipher suites for old clients only; they are never chosen by a client that offers ECDHE. |
| `crypto_password_storage` | N/A | The package never handles or stores user passwords. Sign-in is delegated to tsudev.com via OIDC and only short-lived signed entitlement tokens are cached. |
| `crypto_random` | Met | Installation ids, DPoP keys and DPoP jti values use Random.secure() (a CSPRNG): https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/lib/src/installation/installation_id.dart |
| `delivery_mitm` | Met | The package is delivered as a git dependency over HTTPS from GitHub, pinned to an annotated release tag in the app pubspec.yaml (and locked by commit in pubspec.lock). |
| `delivery_unsigned` | Met | Hashes are never retrieved over plain HTTP. CI tools fetched at build time are verified: Flutter by pinned commit, gitleaks by pinned SHA-256, GitHub Actions by commit SHA: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/.github/workflows/ci.yml |
| `vulnerabilities_fixed_60_days` | Met | No unpatched vulnerability of medium or higher severity: 0 open Dependabot alerts and 0 CodeQL alerts. (The open code-scanning entries are OpenSSF Scorecard posture checks such as Code-Review and Maintained, not vulnerabilities.) |
| `vulnerabilities_critical_fixed` | Met | No critical vulnerability has been reported or is open. |
| `no_leaked_credentials` | Met | No valid credentials in the repository: gitleaks scans the full history on every push and pull request, and GitHub secret scanning with push protection is enabled. The P-256 keys in test/support are public, deterministic test constants that no server trusts: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/.github/workflows/ci.yml |
| `static_analysis` | Met | The Dart analyzer with strict modes runs on every pull request; CodeQL (GitHub default setup) analyzes the GitHub Actions workflows and OpenSSF Scorecard runs weekly: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/.github/workflows/scorecard.yml |
| `static_analysis_common_vulnerabilities` | Unmet | CodeQL has no Dart support, so no security-focused static analyzer covers the Dart code itself (CodeQL covers only the GitHub Actions workflows). Common vulnerability classes in the JWS verifier are covered by negative tests and fuzzing instead. |
| `static_analysis_fixed` | Met | 0 open CodeQL alerts and 0 analyzer findings (the analyzer fails CI on any finding). |
| `static_analysis_often` | Met | The Dart analyzer runs on every pull request and push; CodeQL on every push and pull request; Scorecard weekly. |
| `dynamic_analysis` | Met | A seeded mutation fuzz test runs the entitlement verifier (the only parser of untrusted input) on thousands of mutated tokens and random signed claims/headers in CI on every pull request, checking it only accepts the original token or raises a known rejection: https://github.com/tsudev-org/tsudev-ui-flutter/blob/main/test/entitlement_verifier_fuzz_test.dart |
| `dynamic_analysis_unsafe` | N/A | The project is written only in Dart, a memory-safe language. |
| `dynamic_analysis_enable_assertions` | Met | Tests run with assertions enabled (flutter test enables assert by default) and the verifier checks every input invariant at runtime. |
| `dynamic_analysis_fixed` | Met | The fuzz tests have found no vulnerability; any finding would be fixed before release following SECURITY.md. |
