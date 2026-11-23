# How to use make

<p align="center">
  <b>English</b> &nbsp;|&nbsp;
  <a href="https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-make.zh-CN">Chinese</a>
</p>

`make` is the front door to this repository. It compiles a snippet, runs it,
watches for saves, runs the whole regression suite, and cleans generated
files. You do not need CMake, Visual Studio, or a project file.

This page is the practical guide. The concise command reference is the
[README](https://github.com/Xiang196/test-cpp-code#readme).

All commands below run from the repository root:

```bash
cd ~/src/github/test-cpp-code
```

## 1. Before you start

You need a Linux or WSL environment with:

- `g++` with C++17 support (C++20/23 for snippets that ask for it)
- GNU `make`
- `git`

On Ubuntu/WSL:

```bash
sudo apt install build-essential git
```

Check the toolchain:

```bash
g++ --version
make --version
```

If `make` is missing, that is the first thing to install.

## 2. One-minute tour

```bash
make                                                   # list snippets
make new NAME=cpp17-hello-world DESC="first probe"    # create one
make run S=hello                                       # build and run it
make watch S=hello                                     # rerun on every save
```

`make run` without `S=` runs the most recently modified snippet, so after an
edit you can usually just type `make run`.

Press `Ctrl+C` to stop `make watch`.

## 3. Command reference

| Command | What it does |
| --- | --- |
| `make` or `make list` | List every snippet with its last result, standard, age, and description. |
| `make run S=NAME` | Compile and run one snippet. |
| `make run` | Compile and run the most recently modified snippet. |
| `make watch` | Watch `snippets/`, `include/`, and `data/`; rebuild and rerun on save. |
| `make watch S=NAME` | Watch and run only that snippet. |
| `make test` | Compile and run every snippet; print a pass/fail summary. |
| `make check` | Compile every snippet without running it. |
| `make check S=NAME` | Compile one snippet only. |
| `make new NAME=NAME DESC="..."` | Create `snippets/NAME.cpp` from the template. |
| `make data S=NAME` | Create `data/NAME/` for a file-I/O snippet. |
| `make edit S=NAME` | Open the snippet with `$EDITOR` (default: `code`). |
| `make clean` | Remove `bin/`, `.cache/`, and generated `data/*/out/` files. |
| `make commit` | Interactive changelog + test + commit + push. See the separate guide. |
| `make help` | Show the full built-in help. |

`S=` does not have to be exact. It accepts a snippet name, a file name, a path,
or a unique substring:

```bash
make run S=cpp20-string-view
make run S=cpp20-string-view.cpp
make run S=snippets/cpp20-string-view.cpp
make run S=string
```

If the substring matches more than one snippet, `make` lists the candidates
and asks for a longer name.

## 4. Everyday workflows

### 4.1 Create a snippet

```bash
make new NAME=cpp20-string-view DESC="string_view vs string"
```

This creates `snippets/cpp20-string-view.cpp` with a small header and a
working `main`. Edit it, then:

```bash
make run S=string-view
```

Only the top level of `snippets/` is scanned, so keep the files flat.

### 4.2 Edit while watching

```bash
make watch S=string-view
```

Save the file and the snippet is rebuilt and rerun. Without `S=`, watch
follows the most recently modified snippet. `make watch` also reruns when a
tracked file in `include/` or a fixture under `data/` changes.

### 4.3 Run the regression suite

```bash
make test
```

Every snippet is compiled and run. A snippet passes when its process exits 0.
The summary at the end lists failures, and `make test` returns non-zero, so it
works as a CI gate.

Run one failing snippet with:

```bash
make run S=the-failing-name
```

Extra safety:

```bash
make test SAN=1          # AddressSanitizer + UndefinedBehaviorSanitizer
```

### 4.4 Check compilation only

```bash
make check               # all snippets
make check S=string      # one snippet
```

This is the fast way to catch a syntax error without running the program.

### 4.5 Clean generated files

```bash
make clean
```

This removes `bin/`, `.cache/`, and the generated `data/*/out/` files. It does
not touch snippets, headers, or committed fixtures.

## 5. Snippets that read or write files

Every snippet runs with its working directory set to `data/<snippet-name>/`.
That directory and its `out/` subdirectory are created on demand:

```text
data/
`-- cpp17-fileIO-copy-text/
    |-- input.txt      # fixture: commit this
    `-- out/           # program output: gitignored
```

Create the directory explicitly with:

```bash
make data S=cpp17-fileIO-copy-text
```

Then use relative paths in the snippet:

```cpp
std::ifstream in("input.txt");
std::ofstream out("out/copy.txt");
```

Rules:

- Put input fixtures at the top of `data/NAME/` and commit them.
- Write generated files under `out/` only. It is ignored by git.
- `make clean` removes `out/`, never the fixtures.
- `make run` prints the workdir it used; check that line if a file is missing.
- Use small deterministic fixtures so `make test` is repeatable.

`make test` gives every snippet an empty stdin. A snippet that reads input must
treat EOF as the end and exit; use `make run` when you want to type input.

## 6. Compiler and runtime variables

Override them on the command line:

| Variable | Default | Example |
| --- | --- | --- |
| `STD` | `c++17` | `make run S=foo STD=c++23` |
| `OPT` | `-O0` | `make run S=foo OPT=-O2` |
| `WARN` | `-Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic` | `make check WARN="-Wall -Wextra"` |
| `SAN` | `0` | `make run S=foo SAN=1` |
| `ARGS` | empty | `make run S=foo ARGS="one two"` |
| `CXX` | `g++` | `make run S=foo CXX=clang++` |
| `CXXFLAGS` | empty | `CXXFLAGS="-I/opt/include" make check` |

Standard precedence:

1. `STD=` on the command line
2. `// @std:` in the snippet header
3. the default `c++17`

## 7. Snippet headers

The header comments are optional, but `@desc` is worth writing because
`make list` shows it:

```cpp
// @desc: what this snippet verifies
// @std:  c++20
// @flags: -pthread

#include <tc.hpp>

int main() {
    tc::section("example");
    TC_CHECK(1 + 1 == 2);
    TC_CHECK_EQ(2 + 2, 4);
    return tc::summary();
}
```

- `@desc` is a one-line description.
- `@std` raises the standard for this snippet only.
- `@flags` adds compiler flags, for example `-pthread`.

A snippet can use `TC_CHECK` / `TC_CHECK_EQ` and `return tc::summary()` to
report pass/fail, or just print output and exit 0.

## 8. Naming snippets

- Use lowercase kebab-case ASCII names: `cpp20-string-view.cpp`.
- Pick one prefix axis: standard (`cpp17-`, `cpp20-`, `cpp23-`) or area
  (`stl-`, `tpl-`, `thread-`, `perf-`). `tc-` is reserved for tool demos.
- Keep the name under about 40 characters.
- Put the distinguishing word early, because `S=` is a substring match.
- Avoid `test.cpp`, `tmp.cpp`, and `1.cpp`.
- Renaming a file means renaming its `data/<name>/` directory too.

## 9. Troubleshooting

**`make: command not found`**

```bash
sudo apt install build-essential
```

**`make edit` opens nothing**

It uses `$EDITOR`, falling back to `code`. Set a terminal editor:

```bash
export EDITOR=vim
make edit S=hello
```

**`no snippet matches` or `ambiguous match`**

`S=` was not unique. Run `make list` and use enough of the name to make it
unique.

**`cannot open input.txt`**

The snippet expected a fixture. Check that `data/<name>/input.txt` exists and
look at the `workdir:` line printed by `make run`.

**`make test` hangs**

A snippet reads stdin and does not handle EOF. Treat EOF as the end of input
or use `make run` for interactive input.

**`std::jthread is not a member of std` or similar**

The snippet needs a newer standard. Add `// @std: c++20` (or `c++23`) to its
header, and make sure the compiler supports it.

**A warning became a build error**

The default flags include `-Werror`. Fix the warning or use an explicit cast;
do not remove the strict flags just to get one snippet through.

## 10. Optional shell alias

Put this in `~/.bashrc` to run `tc` from anywhere:

```bash
alias tc='make --no-print-directory -C ~/src/github/test-cpp-code'
```

```bash
tc
tc run S=string-view
tc test
```

## See also

- [README (English)](https://github.com/Xiang196/test-cpp-code#readme)
- [README (Chinese)](https://github.com/Xiang196/test-cpp-code/blob/main/README.zh-CN.md)
- [How to use the commit script](https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-the-commit-script)
- [Changelog](https://github.com/Xiang196/test-cpp-code/blob/main/Changelog.md)
