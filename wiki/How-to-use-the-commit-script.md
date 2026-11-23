# How to use the commit script

<p align="center">
  <b>English</b> &nbsp;|&nbsp;
  <a href="https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-the-commit-script.zh-CN">Chinese</a>
</p>

`make commit` (or `./tools/commit.sh`) is the interactive helper for turning a
working tree into a clean commit. It collects a commit message and a
`Changelog.md` entry, runs the test suite, stages the files, commits, and asks
whether to push.

Use it for normal project commits. Use plain `git` when you need to split a
change into several commits, edit history, or do something the script does not
support.

## 1. What it does

One run of the script:

1. shows the changed files and asks whether untracked files should be included;
2. asks for a one-line commit message;
3. asks for a Changelog category and a one-line entry;
4. shows a preview and asks for confirmation;
5. runs `make test`;
6. inserts the entry under `## [Unreleased]` in `Changelog.md`;
7. stages the files and commits;
8. asks whether to push the current branch.

If tests fail, nothing is committed and `Changelog.md` is not changed.

## 2. Before you start

Make sure git knows who you are:

```bash
git config user.name
git config user.email
```

If either is empty:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

For pushing, the current branch needs an `origin` remote. The script asks before
pushing, and `--no-push` skips it entirely.

`Changelog.md` must exist and contain a `## [Unreleased]` section. The repository
already has both.

## 3. Quick start

```bash
make commit
```

or call the script directly:

```bash
./tools/commit.sh
```

To prefill the commit message:

```bash
make commit M="feat: add string trim"
# same as
./tools/commit.sh -m "feat: add string trim"
```

`make commit` still asks for the Changelog entry and confirmation; `M=` only
skips the message prompt.

## 4. The interactive walkthrough

### 4.1 Changes

The script starts by showing `git status --short` and counts:

```text
== Changes ==
 M README.md
?? snippets/cpp20-string-view.cpp

  staged: 0, modified: 1, untracked: 1
```

If there are untracked files, it asks:

```text
  Stage all changes, including untracked files? [Y/n]
```

- Press Enter or `y`: stage everything with `git add -A`.
- Answer `n`: stage tracked changes only with `git add -u`; untracked files
  stay untracked.

You can skip this prompt with `--tracked-only` (tracked changes only). With
`-y`, the default is to include everything.

If the selected mode has no tracked changes to commit, the script stops with an
error instead of committing only the new Changelog entry.

### 4.2 Commit message

The script asks for one line:

```text
== Commit message ==
  Convention: type: short summary
  Types: feat, fix, docs, refactor, perf, test, chore
  > feat: add string trim
```

Use the Conventional Commits style if you can. Messages longer than 72
characters get a warning. The script commits a single-line message; it does not
add a body.

### 4.3 Changelog entry

The script asks for a category:

```text
== Changelog ==
  Add one bullet under [Unreleased] in Changelog.md.
    1) Added  <- default
    2) Changed
    3) Fixed
    4) Removed
    5) Deprecated
    6) Security
  Category [1]:
```

The default is guessed from the message type:

| Message starts with | Default category |
| --- | --- |
| `feat:` / `feature:` | Added |
| `fix:` / `bugfix:` / `hotfix:` | Fixed |
| `remove:` / `revert:` | Removed |
| anything else | Changed |

Then it asks for the entry text:

```text
  Entry [add string trim]:
```

The default is the message with the recognized prefix removed. Press Enter to
accept it.

The entry is inserted under the chosen `###` heading inside `## [Unreleased]`.
If the category is missing, the script creates it at the end of the Unreleased
section. The entry must be one line of printable ASCII because CI requires all
tracked files except `README.zh-CN.md` and `wiki/*.zh-CN.md` to be pure ASCII.

If the exact bullet already exists in `[Unreleased]`, the script skips the
insertion instead of adding a duplicate.

### 4.4 Preview and confirmation

The script summarizes what it will do:

```text
== Ready ==
  message:   feat: add string trim
  changelog: ### Added
             - add string trim
  stage:     all
  tests:     make test
  Continue? [Y/n]
```

Answer `n` to abort without staging or committing anything.

### 4.5 Tests

The script runs:

```bash
make test
```

The test run unsets `STD` and `TC_FORCE_STD`, so each snippet is compiled with
its own `// @std:` header instead of being forced to C++17 by a nested make.

If the suite fails, the script exits with status 2. Nothing is committed and
`Changelog.md` is left untouched. Fix the failure and run the script again.

Use `--no-test` only when you really need to skip the gate; CI will still run
the tests.

### 4.6 Changelog, stage, commit

After the tests pass, the script:

1. writes the entry to `Changelog.md`;
2. stages with `git add -A` (all) or `git add -u` (tracked only);
3. prints the staged diffstat;
4. runs `git commit -m "<message>"`.

Example:

```text
== Stage ==
 Changelog.md    | 1 +
 README.md       | 3 ++-
 snippets/foo.cpp | 20 +++++++++
 3 files changed, 24 insertions(+), 1 deletion(-)

== Commit ==
[main 1a2b3c4] feat: add string trim
```

### 4.7 Push

Unless `--no-push` was given, the script asks:

```text
  Push to origin/main? [Y/n]
```

- Enter or `y`: `git push -u origin <branch>`.
- `n`: leave the commit local.

With `-y`, the push prompt is skipped and the branch is pushed automatically.
Combine `-y` with `--no-push` when you want a fully non-interactive local
commit.

If the HEAD is detached, the script warns and skips pushing. If the push itself
fails (network, credentials, rejected branch), the commit remains local and the
script exits non-zero.

## 5. Options

| Option | Meaning |
| --- | --- |
| `-m MSG`, `--message MSG` | Use this commit message instead of asking. |
| `--changelog-category CAT` | Category: Added, Changed, Fixed, Removed, Deprecated, Security. Case-insensitive. |
| `--changelog-entry TEXT` | One-line Changelog entry; skips the entry prompt. |
| `--no-changelog` | Do not modify `Changelog.md`. |
| `--tracked-only` | Stage tracked changes only; leave untracked files alone. |
| `--no-test` | Skip `make test`. |
| `--no-push` | Commit locally; do not push. |
| `-y`, `--yes` | Accept confirmation and Changelog defaults; with no `--no-push`, push automatically. |
| `-h`, `--help` | Show the built-in help. |

The script also accepts a bare message argument for compatibility:

```bash
./tools/commit.sh "docs: update examples"
```

## 6. Non-interactive recipes

Fully automatic, local commit, custom Changelog entry:

```bash
./tools/commit.sh \
  -m "fix: stop double free in parser" \
  --changelog-category Fixed \
  --changelog-entry "Stop a double free when the parser rejects input." \
  --tracked-only -y --no-push
```

Fully automatic and push:

```bash
./tools/commit.sh -m "docs: update make guide" -y
```

Commit all changes but skip the Changelog update:

```bash
./tools/commit.sh -m "chore: refresh CI cache" --no-changelog -y --no-push
```

`--no-changelog` is an escape hatch. The project convention is that every
commit updates `Changelog.md`.

## 7. Staging details

- Default: `git add -A`, including untracked files.
- `--tracked-only`: `git add -u`, tracked modifications and deletions only.
- Files you already staged stay staged; the script does not unstage them.
- `make clean` artifacts (`bin/`, `.cache/`, `data/*/out/`) are ignored and
  never committed.
- If you have only untracked files and choose tracked-only, the script stops:
  there is nothing tracked to commit.

## 8. Troubleshooting

**`nothing to commit (working tree clean)`**

There are no changes. The script exits 0 without asking anything.

**`no tracked changes to commit`**

You selected tracked-only mode, but every change is untracked. Either let the
script include untracked files or `git add` the files you want first.

**`Changelog.md has no '## [Unreleased]' section`**

Restore the section or add it manually. The script will not guess where old
entries should go.

**`Changelog.md must stay ASCII`**

Use an English entry. The commit message itself may contain non-ASCII text, but
the Changelog entry may not.

**`make test` failed**

Nothing was committed. Read the failing snippet from the output, run
`make run S=name`, fix it, and repeat. Use `--no-test` only as a deliberate
escape hatch.

**`Could not read from remote repository` / push rejected**

The commit is already local. Fix credentials or pull/rebase, then `git push`.

**A long Changelog entry**

The entry is written as one bullet line. Keep it short and put details in the
commit message or the wiki/README instead.

## See also

- [How to use make](https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-make)
  (also covers publishing the wiki with `make wiki`)
- [Changelog](https://github.com/Xiang196/test-cpp-code/blob/main/Changelog.md)
- [README (English)](https://github.com/Xiang196/test-cpp-code#readme)
- [README (Chinese)](https://github.com/Xiang196/test-cpp-code/blob/main/README.zh-CN.md)
