# test-cpp-code

A scratchpad for small C++ probes: **one `.cpp` file = one runnable program.**
`make run` compiles and runs it, `make watch` reruns on every save, and
`make test` runs the whole folder and reports pass/fail.

<p align="center">
  <b>English</b> &nbsp;|&nbsp; <a href="README.zh-CN.md">Chinese</a>
</p>

> Verified on this machine's WSL: Ubuntu, g++ 15.2.0, GNU Make 4.4.1.
> Everything below runs in a WSL terminal.
> All source files, scripts, and command output are plain ASCII English.

The source code in this repository was written by **DSH (DeepSeek Harness)**.
See [License and attribution](#license-and-attribution).

## 30-second start

```bash
cd ~/src/github/test-cpp-code

make                                     # list current snippets
make new NAME=string-view DESC="string_view vs string"
make watch S=string-view                 # edit, save, output rebuilds and reruns
```

`Ctrl+C` quits watch. The alias at the bottom of this file saves the `cd`.

## The three everyday workflows

| What you want | Command |
| --- | --- |
| Verify a new syntax or library feature while editing | `make new NAME=xxx`, then `make watch S=xxx` |
| Tweak an existing snippet | `make run S=xxx` |
| Check that everything still compiles and passes | `make test` |

`make run` without `S=` runs the most recently modified snippet, so right after
an edit you can just type `make run`.

## Commands

```text
make                    list all snippets (default target)
make run S=NAME         compile and run one snippet
make run                compile and run the most recently modified snippet
make watch              watch snippets/, rebuild and rerun on save
make watch S=NAME       watch only that snippet
make test               compile + run all, print a pass/fail summary
make check              compile only (fast syntax check)
make dates              list snippets by creation date (validates @created)
make new NAME=NAME      create a snippet (DESC="one line" optional)
make data S=NAME        create data/NAME/ for a file-I/O snippet
make edit S=NAME        open with $EDITOR (default: code)
make clean              remove bin/, .cache/ and generated data/*/out/
make commit             interactive: message + Changelog, test, commit, push
make commit M="msg"     same, with the message already filled in
make wiki               publish wiki/ to the GitHub wiki repo (commit + push)
make help               full help
```

Names do not have to be exact: `make run S=string` resolves to
`cpp20-string-view` as long as the match is unique; ambiguous matches are
listed so you can pick a full name. `S=` also accepts a file name or a path
(`S=cpp20-string-view.cpp`, `S=snippets/cpp20-string-view.cpp`), so tab
completion and pasted paths work.

## Committing

`make commit` (or `./tools/commit.sh`) is interactive. It shows the changed
files, asks for a Conventional Commits message and a `Changelog.md` entry
(category plus one-line text), runs `make test`, stages the files, commits,
and offers to push:

```bash
make commit
```

To prefill parts of it:

```bash
./tools/commit.sh -m "docs: update default flags" \
  --changelog-category Changed \
  --changelog-entry "Document the default flags and commit workflow."
```

The entry is inserted under `## [Unreleased]`. It has to stay ASCII because CI
requires every tracked file except `README.zh-CN.md` to be pure ASCII.

Useful options: `--no-test`, `--no-push`, `--no-changelog`, `--tracked-only`
(leave untracked files alone), and `-y` (accept defaults and skip
confirmations; this also pushes unless `--no-push` is given).

`make commit M="..."` is a shortcut for `./tools/commit.sh -m "..."`.

### Publishing the wiki

The Markdown under `wiki/` is the source of truth for the
[GitHub wiki](https://github.com/Xiang196/test-cpp-code/wiki). `make wiki`
copies it into the separate wiki clone (default: `../test-cpp-code.wiki`),
commits, and pushes:

```bash
make wiki
make wiki M="docs: refresh the make guide"
make wiki WIKI_DIR=~/src/github/test-cpp-code.wiki
```

Use `./tools/wiki.sh --dry-run` to see the diff without writing anything,
`--no-push` to commit locally only, and `--delete` to also remove wiki pages
that no longer exist under `wiki/`. The clone must be clean; the script
fast-forwards it before copying. `WIKI_URL` overrides the remote used when the
clone does not exist.

## Snippet header convention

These four comments are optional for the build, but `@desc` is worth writing
(`make list` shows it) and `make new` stamps `@created` for you:

```cpp
// @desc:    one-line description of what this probe verifies
// @created: 2026-11-23   <- creation date, ISO YYYY-MM-DD
// @std:     c++23        <- overrides the default standard
// @flags:   -pthread     <- extra compiler flags (threads, special libs, ...)

#include <tc.hpp>

int main() {
    tc::section("string_view");
    TC_CHECK(std::string("hello").starts_with("he"));
    TC_CHECK_EQ(std::string("abc").size(), 3u);
    return tc::summary();   // returns 1 on failure, so make test marks it red
}
```

- **Want pass/fail**: use `TC_CHECK` / `TC_CHECK_EQ` from `include/tc.hpp` and
  `return tc::summary()`. `make test` then knows which snippet broke.
- **Just want output**: plain `std::cout` is fine; exit code 0 counts as a pass.
- **`@created` is the creation date, not the last edit.** It uses ISO
  `YYYY-MM-DD`; keep it when renaming a snippet, and give a copy today's date.
  `make dates` lists snippets oldest-first and rejects missing, malformed, or
  impossible dates (`2026-2-3`, `2026-02-30`).

Standard precedence: **command-line `STD=` > `// @std:` header > default `c++17`**.

## Default flags

Every snippet is compiled with:

```text
-std=c++17 -O0 -Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic
```

- `-Werror` turns any warning into a build failure, so `make test` is strict.
- `-Wconversion` flags implicit narrowing; add an explicit `static_cast` or
  change the types when it complains.
- `-Wno-unused-result` keeps functions like `write(2)` quiet when the result is
  intentionally ignored.
- `-Wvla` rejects variable-length arrays (a GNU extension, not standard C++).
- A snippet may raise the standard with `// @std: c++23`; override everything
  for one run with `STD=c++23`, `WARN="-Wall -Wextra"`, `OPT=-O2`, or
  `CXXFLAGS="..."`.

## Naming snippets

`make list` sorts by file name and `make run S=...` resolves by exact match then
unique substring, so the file name is the handle you actually type.

- **lowercase kebab-case, ASCII only**: `cpp23-expected.cpp`, not `Test.CPP`.
- **pick one prefix axis for the whole folder** - either the standard
  (`cpp17-`, `cpp20-`, `cpp23-`) or the area (`stl-`, `tpl-`, `thread-`,
  `perf-`, `idiom-`). `tc-` is reserved for snippets that demo the tool itself.
- **the rest is the subject**: `cpp20-string-view.cpp`,
  `stl-map-insert-order.cpp`, `thread-jthread-stop-token.cpp`.
- **keep it under about 40 characters** so it still fits one line in `make list`.
- **put the distinguishing word early**: `S=` does substring matching, so
  `string-view` and `string-view-trim` both match `S=string-view`, while
  `S=trim` stays unambiguous.
- `@desc` carries the *why*; the name only has to make the snippet findable.

Avoid `test.cpp`, `tmp.cpp`, `1.cpp`: they collide, make `make run` ambiguous,
and say nothing about what the snippet does. When a scratch probe becomes
something worth keeping, rename it:
`git mv snippets/scratch-x.cpp snippets/cpp23-x.cpp`.

## Snippets that read or write files

A snippet that opens files runs with its working directory set to
`data/<snippet-name>/`, never the repository root:

```text
data/
`-- cpp17-fileIO-copy-text/
    |-- input.txt      # fixture: committed, small, plain ASCII
    `-- out/           # generated: gitignored, wiped by make clean
```

Rules:

- **One directory per snippet, named exactly like the `.cpp`.** `make data
  S=NAME` creates `data/NAME/out/`; `make run` and `make test` create it on
  demand too, so a read-only probe simply starts empty.
- **Fixtures live at the top of the directory and are committed.** Keep them
  small and deterministic: CI runs `make test` on a fresh checkout, and a
  missing input file must fail the snippet instead of hiding the problem.
- **Outputs go under `out/`.** It is created for you and ignored by git, so
  `git status` stays clean no matter what the probe writes.
- **Use relative paths.** The CWD is already the data directory, so
  `std::ifstream("input.txt")` and `std::ofstream("out/copy.txt")` are all
  you need - no `../..` path juggling and no absolute paths.
- **Never write outside `out/`.** `make clean` deletes `bin/`, `.cache/` and
  every `data/*/out/`; fixtures are never touched.
- **`make test` gives every snippet an empty stdin.** A snippet that reads
  input must handle EOF (`if (std::cin.eof()) break;`), or `make test` can
  never finish. Use `make run` when you want to type input interactively.
- **Renaming or deleting a snippet means its data directory too.**
  `git mv snippets/old.cpp snippets/new.cpp` plus `git mv data/old data/new`;
  when a probe is no longer worth keeping, `git rm -r data/old` as well.
- **Check the workdir line.** `make run` prints the directory it used, which
  is the first thing to look at when a file seems missing.

`make list` also prints a `data fixtures:` line naming the snippets that have
fixtures, so the folder stays discoverable.

Assert on a generated file by reading it back with `TC_CHECK`; keep the
fixture deterministic so `make test` still means something:

```cpp
std::ifstream back("out/copy.txt");
std::string line;
TC_CHECK(static_cast<bool>(std::getline(back, line)));
```

Large binary fixtures (images, archives) do not belong in git. Keep a tiny
ASCII fixture for CI, or move that probe to a real CMake project.

## Layout

```text
test-cpp-code/
|-- Makefile          # entry points and variables
|-- Changelog.md      # keep-a-changelog release notes; every commit updates it
|-- snippets/         # your snippets: one .cpp = one program (the only place you edit daily)
|-- data/             # per-snippet working dirs: fixtures committed, out/ ignored
|-- include/tc.hpp    # optional tiny assertion header, zero dependencies
|-- tools/tc.sh       # the actual engine: list/run/watch/test/check/dates/new/data
|-- tools/commit.sh   # interactive message + Changelog + test + commit + push
|-- tools/wiki.sh     # publish wiki/ to the separate GitHub wiki clone
|-- bin/              # build products (auto-generated, gitignored)
`-- .cache/           # compiler/run logs and last results (auto-generated, gitignored)
```

- **Zero configuration for new snippets**: drop a `.cpp` into `snippets/` and
  `make run` / `make list` immediately work. Probing a language feature should
  not start with five minutes of project setup.
- **Products and logs stay out of the way**: everything generated lives in
  `bin/`, `.cache/` and `data/*/out/`, and `make clean` wipes all three.
- **The folder is self-contained**: all paths are relative, so you can copy the
  whole thing somewhere else (for example into the WSL home directory for
  faster builds, see FAQ).

## Variables

```bash
make run S=foo STD=c++23        # change standard
make run S=foo OPT=-O2          # change optimization
make run S=foo SAN=1            # ASan + UBSan
make run S=foo ARGS="a b"       # pass command-line arguments
make run S=foo CXX=clang++      # other compiler
CXXFLAGS="-I/usr/include/x" make check   # extra flags
```

## Why it is shaped like this

1. **One `main` per snippet**: a compile error, a crash, or an infinite loop
   only affects that one file. The exit code is the natural "did this behave as
   expected" signal, which is what `make test` aggregates.
2. **No project files to maintain**: there is no CMakeLists or .vcxproj to keep
   in sync when you add a probe.
3. **The Makefile is only the surface**: the real logic lives in
   `tools/tc.sh`, because a watch loop and header parsing are painful to write
   and read inside make. Adding a feature means editing one file.
4. **Regression is one command**: `make test` makes "every probe still
   compiles and still passes" testable instead of a memory exercise.
5. **File I/O is sandboxed per snippet**: every snippet runs inside
   `data/<name>/`, so a probe that writes files cannot dirty the repository
   root or another probe's fixtures. `make test` stays repeatable.

## When to move on

- **Multiple translation units, multiple targets, third-party libraries** (for
  example GoogleTest) -> create a separate CMake project. Keep this folder for
  single-file probes; the two do not conflict.
- **Reading stdin for algorithm practice** -> have the snippet use `std::cin`;
  `make run S=xxx` then lets you type input, or use `echo 1 2 | ./bin/xxx`.

## FAQ

**Why does it live in `~/src/github` instead of on `/mnt/c`?**
It started under `/mnt/c` (the Windows drive), where compiling a single snippet
took about 1.2 s. It now lives on WSL's native filesystem, which builds the same
snippet several times faster and is a normal git repository that can be cloned
anywhere.

**Where do I put extra compiler flags or include paths?**
Use `CXXFLAGS=` (appended) or the `@flags:` header. Shared headers go into
`include/` (already on the include path via `-I`).

**No make in WSL?**
`sudo apt install build-essential`.

**`make edit` does not open anything?**
It runs `$EDITOR`, falling back to `code`. Without VS Code, run
`export EDITOR=vim` (or nano), then `make edit S=NAME`.

**Can I group snippets into subfolders?**
Only the top level of `snippets/` is scanned. Use filename prefixes instead
(`cpp23-`, `stl-`, `tpl-`); `make list` sorts by name, so they group naturally.

## Optional: a shell alias

Add this to `~/.bashrc` and run `tc` from anywhere:

```bash
alias tc='make --no-print-directory -C ~/src/github/test-cpp-code'
```

```bash
tc                      # list snippets (make's default target)
tc run S=string-view
tc watch
```

## License and attribution

MIT - see [LICENSE](LICENSE).

The source code in this repository was written by DSH (DeepSeek Harness).
Maintained by [Xiang196](https://github.com/Xiang196).
