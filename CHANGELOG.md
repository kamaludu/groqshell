[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)

# Changelog

## [Unreleased]
- Additional documentation improvements
- Optional enhancements for extras and test suites

---

## [1.0.0] – 2026‑01‑22
### Added
- Full security‑hardened release after STEP 5.6 → STEP 7.2 audit cycle
- Dynamic model whitelist using Groq Models API (`/openai/v1/models`)
- External help system (`extras/docs/help.txt`)
- Provider module system (`extras/providers/`)
- Optional advanced tools:
  - `extras/security/verify.sh` (provider integrity checks)
  - `extras/security/validate-env.sh` (environment validation)
  - `extras/test/json-sse-suite.sh` (JSON/SSE parsing tests)
- `--install-extras` installer (idempotent, safe)
- Interactive provider selection (`--provider` without argument)
- Secure temporary directory handling (no `/tmp`, strict permissions)
- Automatic output saving with configurable threshold
- Streaming and non‑streaming response handling
- Debug mode with preserved temp files
- Complete documentation set: README, README‑it, INSTALL, SECURITY, CHANGELOG

### Changed
- Major hardening of provider loading:
  - directory permission checks
  - file‑level owner/permission/symlink checks
  - minimal TOCTOU mitigation
- Improved JSON escaping and SSE parsing robustness
- Unified banner and header across all scripts
- More consistent CLI behavior and error messages

### Fixed
- Removed unsafe fallback temp paths
- Eliminated legacy parsing logic and deprecated model fallbacks
- Corrected edge cases in model auto‑selection policy

---

## [0.12.0] – 2026‑01‑19
### Added
- Core CLI options: `--refresh-models`, `--list-models`, `--dry-run`, `--debug`
- Automatic output saving beyond threshold
- Documentation: README, INSTALL, CHANGELOG, CONTRIBUTING

---

## [0.11.1] – 2026‑01‑18
### Added
- First public version with Groq API model whitelist support

---

## [Initial]
- Minimal repository structure
- First prototype of `groqbash` with basic model refresh
- Essential documentation

---

*Note: Some sections of the codebase were drafted or refined with the assistance of AI tools.  
Architecture, design, and final decisions remain manually curated.*
