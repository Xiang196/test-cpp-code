# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Every commit should add its user-visible changes under `[Unreleased]`; when a
release is tagged, that section is renamed to the version and a new
`[Unreleased]` section is opened.

## [Unreleased]

### Added

- Per-snippet file-I/O workspace: every snippet now runs with its current
  directory set to `data/<snippet-name>/`, so relative paths such as
  `input.txt` and `out/copy.txt` resolve inside its own fixture directory.
- `make data S=NAME` creates `data/NAME/` and its generated-output
  subdirectory `out/`.
- `make list` prints a `data fixtures:` line naming snippets that have
  committed fixtures.
- Demo snippet `cpp17-fileIO-copy-text.cpp` and its committed fixture
  `data/cpp17-fileIO-copy-text/input.txt`.
- `Changelog.md` and the rule that every commit updates it.
- Add bilingual wiki guides for make and the commit script

### Changed

- `make run` reports the working directory it uses before executing a
  snippet.
- `make watch` also reruns when a fixture under `data/` changes; generated
  files in `data/*/out/` are ignored to avoid feedback loops.
- `make clean` now removes `bin/`, `.cache/`, and generated
  `data/*/out/` files, while keeping committed fixtures.
- `make test` runs every snippet with an empty stdin, so the suite cannot
  wait for typed input.
- Both READMEs document the per-snippet data layout and the file-I/O rules.
- `make commit` now prompts for a commit message and a `Changelog.md` entry,
  runs tests, stages, commits, and offers to push.

### Fixed

- `cpp17-course-input-test.cpp` no longer loops forever when stdin reaches
  EOF; `make test` therefore terminates.
- `cpp17-fileIO-copy-text.cpp` now reports a clear error and exits non-zero
  when its input fixture cannot be opened.
- `make commit` no longer forces C++17 over a snippet's `// @std:` header when
  it invokes `make test` through the Makefile.

## [0.1.0] - 2026-11-20

### Added

- One-command snippet workbench: `make run`, `make watch`, `make test`,
  `make check`, and `make new`, with the engine in `tools/tc.sh`.
- Default C++17 builds with strict warnings, plus per-snippet `// @std:` and
  `// @flags:` overrides.
- `include/tc.hpp` with `TC_CHECK` and `TC_CHECK_EQ` for snippets that
  should report pass/fail.
- English and Chinese READMEs and a CI workflow that compiles and runs every
  snippet, including an AddressSanitizer/UBSan pass.
- `tools/commit.sh` to run the test suite, stage all changes, commit, and
  push.
