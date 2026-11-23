#!/usr/bin/env bash
# ============================================================================
# test-cpp-code engine.
#
#   The Makefile is only a shortcut layer; everything real lives here.
#   Add new commands in this file only.
#
#   Snippets may start with optional metadata comments:
#       // @desc:  one-line description shown by `make list`
#       // @std:   c++23         override the default standard
#       // @flags: -pthread      extra compiler flags
#
#   File-I/O convention: every snippet runs with its working directory set to
#   data/<snippet-name>/, which is created on demand. Input fixtures live at
#   the top of that directory and are committed; generated files go to out/,
#   which is gitignored. So a snippet can just use "input.txt" and
#   "out/result.txt" instead of juggling paths. See `make help` and README.
#
#   You can also call the engine directly, bypassing make:
#       ./tools/tc.sh run string-view
# ============================================================================
set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT" || { echo "cannot cd into $ROOT" >&2; exit 1; }

SNIPPETS=snippets
INCLUDE=include
DATA=data
BIN=bin
CACHE=.cache

# ---- Configurable; the Makefile exports its variables, so ---------------
# ---- `make run S=foo STD=c++23 SAN=1` reaches this script. --------------
CXX=${CXX:-g++}
STD=${STD:-c++17}
OPT=${OPT:--O0}
WARN=${WARN:--Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic}
CXXFLAGS=${CXXFLAGS:-}
SAN=${SAN:-0}
ARGS=${ARGS:-}

# ---- Colors (plain ASCII output; color only when attached to a tty) ------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B=$'\e[1m'; DIM=$'\e[2m'; G=$'\e[32m'; R=$'\e[31m'; N=$'\e[0m'
else
    B=''; DIM=''; G=''; R=''; N=''
fi

err()  { printf '%sERROR:%s %s\n' "$R" "$N" "$*" >&2; }
die()  { err "$@"; exit 1; }
ok()   { printf '%s[ok]%s %s\n' "$G" "$N" "$*"; }
bad()  { printf '%s[!!]%s %s\n' "$R" "$N" "$*"; }

now_s()  { date +%s; }
now_ms() { date +%s%3N; }

mkdir -p "$SNIPPETS" "$INCLUDE" "$BIN" "$CACHE"

# ---- Snippet lookup ------------------------------------------------------
snippet_names() {
    find "$SNIPPETS" -maxdepth 1 -type f -name '*.cpp' -printf '%f\n' 2>/dev/null \
        | sed 's/\.cpp$//' | sort
}

# name -> snippet name. Accepts all of these forms:
#   cpp20-string-view                  snippet name
#   cpp20-string-view.cpp              file name
#   snippets/cpp20-string-view.cpp     path
#   /abs/path/to/cpp20-string-view.cpp absolute path
# Exact match first, then a unique substring match.
resolve() {
    local want=${1:-} n
    want=${want%.cpp}
    if [ -z "$want" ]; then
        err "no snippet name given"
        return 1
    fi

    # If it names an existing file (with or without the .cpp suffix),
    # keep only the basename.
    if [ -f "$want" ] || [ -f "$want.cpp" ]; then
        want=$(basename -- "$want")
    fi
    # Drop a leading ./ or snippets/ prefix.
    want=${want#./}
    want=${want#snippets/}

    if [ -f "$SNIPPETS/$want.cpp" ]; then
        printf '%s\n' "$want"
        return 0
    fi
    local hits=()
    while IFS= read -r n; do
        case $n in
            *"$want"*) hits+=("$n") ;;
        esac
    done < <(snippet_names)
    case ${#hits[@]} in
        0)
            err "no snippet matches: $want"
            printf 'available: %s\n' "$(snippet_names | tr '\n' ' ')" >&2
            return 1
            ;;
        1)
            printf '%s\n' "${hits[0]}"
            ;;
        *)
            err "ambiguous match: $want -> ${hits[*]}"
            return 1
            ;;
    esac
}

# Most recently modified snippet.
newest() {
    local f
    f=$(find "$SNIPPETS" -maxdepth 1 -type f -name '*.cpp' -printf '%T@ %f\n' 2>/dev/null \
        | sort -rn | head -n 1 | cut -d' ' -f2-)
    [ -n "$f" ] || return 1
    printf '%s\n' "${f%.cpp}"
}

# ---- Metadata from the snippet header ------------------------------------
meta() {
    sed -n "s/^[[:space:]]*\/\/[[:space:]]*@$2:[[:space:]]*//p" "$1" | head -n 1
}

# Standard precedence: explicit STD= from the command line > // @std: > default.
std_of() {
    local s
    if [ "${TC_FORCE_STD:-0}" = "1" ] && [ -n "${STD:-}" ]; then
        printf '%s\n' "$STD"
        return 0
    fi
    s=$(meta "$1" std)
    printf '%s\n' "${s:-$STD}"
}

# ---- Build ---------------------------------------------------------------
# Returns 0 on success, 1 on failure; compiler output lives in
# .cache/<name>.build.log
build_one() {
    local name=$1
    local src="$SNIPPETS/$name.cpp"
    local out="$BIN/$name"
    local std extra
    [ -f "$src" ] || { err "source not found: $src"; return 1; }

    std=$(std_of "$src")
    extra=$(meta "$src" flags)

    local -a cmd=("$CXX" "-std=$std")
    # WARN / OPT / CXXFLAGS are intentionally unquoted so values like
    # "-O2 -march=native" still work.
    # shellcheck disable=SC2206
    cmd+=($WARN $OPT ${CXXFLAGS:-})
    if [ "$SAN" != "0" ] && [ -n "$SAN" ]; then
        cmd+=(-fsanitize=address,undefined -fno-omit-frame-pointer -g)
    fi
    if [ -n "$extra" ]; then
        # shellcheck disable=SC2206
        cmd+=($extra)
    fi
    cmd+=(-I"$INCLUDE" "$src" -o "$out")

    if "${cmd[@]}" >"$CACHE/$name.build.log" 2>&1; then
        return 0
    fi
    return 1
}

print_build_fail() {
    local name=$1
    bad "compile failed: $name"
    sed 's/^/    /' "$CACHE/$name.build.log"
}

# ---- Per-snippet working directory ---------------------------------------
# Every snippet runs with CWD = data/<name>/, so a snippet that reads
# "input.txt" or writes "out/copy.txt" only ever touches its own fixture
# folder, never the repository root or another snippet's files. The directory
# and its out/ subdirectory are created on demand; only fixtures (files
# outside out/) are meant to be committed.
workdir_of() { printf '%s/%s\n' "$DATA" "$1"; }

prepare_workdir() {
    local dir
    dir=$(workdir_of "$1")
    mkdir -p "$dir/out" || { err "cannot create $dir"; return 1; }
}

# Runs the compiled snippet inside its data directory. Callers redirect output
# when they need to (make test writes .cache/<name>.run.log).
run_in_data() {
    local name=$1 bin="$ROOT/$BIN/$1"
    prepare_workdir "$name" || return 1
    (
        cd -- "$(workdir_of "$name")" || exit 1
        if [ -n "$ARGS" ]; then
            # shellcheck disable=SC2086
            "$bin" $ARGS
        else
            "$bin"
        fi
    )
}

# ---- Run history (used by `make list`) -----------------------------------
record() {  # name exit-code
    printf '%s %s\n' "$2" "$(now_s)" >"$CACHE/$1.status"
}

# Compact relative age, pure ASCII: 5s / 2m / 3h / 2d
ago() {
    local then=${1:-0} now d
    now=$(now_s)
    d=$((now - then))
    if [ "$d" -lt 0 ]; then d=0; fi
    if [ "$d" -lt 60 ]; then
        printf '%ds' "$d"
    elif [ "$d" -lt 3600 ]; then
        printf '%dm' "$((d / 60))"
    elif [ "$d" -lt 86400 ]; then
        printf '%dh' "$((d / 3600))"
    else
        printf '%dd' "$((d / 86400))"
    fi
}

# ---- Run one snippet -----------------------------------------------------
run_one() {
    local name=$1
    local src="$SNIPPETS/$name.cpp"
    local std rc t_build t_run0 t_run1

    [ -f "$src" ] || { err "snippet not found: $name"; return 1; }
    std=$(std_of "$src")

    printf '%s> %s%s %s[%s]%s\n' "$B" "$name" "$N" "$DIM" "$std" "$N"

    t_build=$(now_ms)
    if ! build_one "$name"; then
        print_build_fail "$name"
        record "$name" 1
        return 1
    fi
    t_build=$(( $(now_ms) - t_build ))
    printf '%s  compiled in %dms%s\n' "$DIM" "$t_build" "$N"
    printf '%s  workdir: %s%s\n' "$DIM" "$(workdir_of "$name")" "$N"

    t_run0=$(now_ms)
    run_in_data "$name"
    rc=$?
    t_run1=$(( $(now_ms) - t_run0 ))

    record "$name" "$rc"
    if [ "$rc" -eq 0 ]; then
        printf '%s[ok] exit 0, ran %dms%s\n' "$G" "$t_run1" "$N"
    else
        printf '%s[!!] exit %d, ran %dms%s\n' "$R" "$rc" "$t_run1" "$N"
    fi
    return "$rc"
}

# ---- make list -----------------------------------------------------------
cmd_list() {
    local names count n icon stdtag desc age status rc ts data_names=''
    names=$(snippet_names)
    if [ -z "$names" ]; then
        printf 'no snippets yet.\n\n'
        printf '  make new NAME=hello DESC="first snippet"\n'
        return 0
    fi
    count=$(printf '%s\n' "$names" | wc -l)
    if [ "$count" -eq 1 ]; then
        printf '%s1 snippet%s  %s(%s/)%s\n\n' "$B" "$N" "$DIM" "$SNIPPETS" "$N"
    else
        printf '%s%d snippets%s  %s(%s/)%s\n\n' "$B" "$count" "$N" "$DIM" "$SNIPPETS" "$N"
    fi

    while IFS= read -r n; do
        if [ -f "$CACHE/$n.status" ]; then
            read -r rc ts <"$CACHE/$n.status" || true
            if [ "${rc:-1}" = "0" ]; then
                icon="${G}[ok]${N}"
            else
                icon="${R}[!!]${N}"
            fi
            age=$(ago "${ts:-0}")
        else
            icon="${DIM}[--]${N}"
            age='never'
        fi
        stdtag="[$(std_of "$SNIPPETS/$n.cpp")]"
        desc=$(meta "$SNIPPETS/$n.cpp" desc)
        if [ -n "$desc" ]; then
            printf '  %s  %-40s %s%-9s%s %-6s %s\n' \
                "$icon" "$n.cpp" "$DIM" "$stdtag" "$N" "$age" "$desc"
        else
            printf '  %s  %-40s %s%-9s%s %-6s\n' \
                "$icon" "$n.cpp" "$DIM" "$stdtag" "$N" "$age"
        fi
        if [ -d "$DATA/$n" ] && [ -n "$(find "$DATA/$n" -mindepth 1 -maxdepth 2 \
            -type f -not -path '*/out/*' -print -quit 2>/dev/null)" ]; then
            data_names+=" $n"
        fi
    done <<<"$names"

    if [ -n "$data_names" ]; then
        printf '\n%sdata fixtures:%s%s\n' "$DIM" "$N" "$data_names"
    fi

    printf '\n%smake run S=NAME%s runs one (no S = most recently modified)   %smake watch%s save to rerun\n' \
        "$DIM" "$N" "$DIM" "$N"
}

# ---- make run ------------------------------------------------------------
cmd_run() {
    local target=${1:-}
    if [ -z "$target" ]; then
        target=$(newest) || die "no snippets yet; create one with: make new NAME=xxx"
    fi
    target=$(resolve "$target") || exit 1
    run_one "$target"
}

# ---- make test -----------------------------------------------------------
cmd_test() {
    local names n rc t_all0 t_all1 pass=0 fail=0 failed=() t0 t1
    names=$(snippet_names)
    [ -n "$names" ] || die "no snippets yet"

    t_all0=$(now_ms)
    printf '%s> all snippets: compile + run%s\n\n' "$B" "$N"

    while IFS= read -r n; do
        printf '  %-42s' "$n"
        if ! build_one "$n"; then
            printf '%s[!!] compile failed%s\n' "$R" "$N"
            sed 's/^/      /' "$CACHE/$n.build.log"
            record "$n" 1
            fail=$((fail + 1))
            failed+=("$n")
            continue
        fi
        t0=$(now_ms)
        # Empty stdin: make test must never sit waiting for typed input on a
        # terminal. Snippets that read stdin see EOF and should exit cleanly;
        # use `make run S=...` when you want to type input interactively.
        run_in_data "$n" </dev/null >"$ROOT/$CACHE/$n.run.log" 2>&1
        rc=$?
        t1=$(( $(now_ms) - t0 ))
        record "$n" "$rc"
        if [ "$rc" -eq 0 ]; then
            printf '%s[ok]%s %6dms\n' "$G" "$N" "$t1"
            pass=$((pass + 1))
        else
            printf '%s[!!] exit %d%s\n' "$R" "$rc" "$N"
            tail -n 15 "$CACHE/$n.run.log" | sed 's/^/      /'
            fail=$((fail + 1))
            failed+=("$n")
        fi
    done <<<"$names"

    t_all1=$(( $(now_ms) - t_all0 ))
    printf '\n'
    if [ "$fail" -eq 0 ]; then
        printf '%s[ok] %d passed%s  %s(%dms)%s\n' "$G" "$pass" "$N" "$DIM" "$t_all1" "$N"
    else
        printf '%s[!!] %d passed, %d failed%s  %s(%dms)%s\n' \
            "$R" "$pass" "$fail" "$N" "$DIM" "$t_all1" "$N"
        printf '  failed: %s\n' "${failed[*]}"
        printf '  details: make run S=%s\n' "${failed[0]}"
        return 1
    fi
}

# ---- make check ----------------------------------------------------------
cmd_check() {
    local target=${1:-} names n rc=0
    if [ -n "$target" ]; then
        target=$(resolve "$target") || exit 1
        if build_one "$target"; then
            ok "compiled: $target"
        else
            print_build_fail "$target"
            exit 1
        fi
        return 0
    fi
    names=$(snippet_names)
    [ -n "$names" ] || die "no snippets yet"
    while IFS= read -r n; do
        if build_one "$n"; then
            ok "compiled: $n"
        else
            print_build_fail "$n"
            rc=1
        fi
    done <<<"$names"
    return "$rc"
}

# ---- make new ------------------------------------------------------------
cmd_new() {
    local name=${1:-} desc=${2:-}
    if [ -z "$name" ]; then
        die 'usage: make new NAME=snippet-name [DESC="one line"]'
    fi
    case $name in
        *[!A-Za-z0-9._-]*) die "invalid name: $name (use letters, digits, . _ -)" ;;
    esac
    local f="$SNIPPETS/$name.cpp"
    [ -e "$f" ] && die "already exists: $f"
    [ -n "$desc" ] || desc='TODO: what is this snippet verifying?'

    {
        printf '// @desc: %s\n' "$desc"
        printf '// @std: %s\n' "$STD"
        printf '//\n'
        printf '// Write what you want to verify here. Use TC_CHECK from include/tc.hpp\n'
        printf '// if the snippet should report pass/fail; otherwise just print with\n'
        printf '// std::cout and exit 0.\n'
        printf '\n#include <tc.hpp>\n\n'
        printf 'int main() {\n'
        printf '    tc::section("example");\n'
        printf '    TC_CHECK(1 + 1 == 2);\n'
        printf '\n'
        printf '    return tc::summary();\n'
        printf '}\n'
    } >"$f"

    ok "created $f"
    printf '  next: make run S=%s    or    make watch S=%s\n' "$name" "$name"
}

# ---- make watch ----------------------------------------------------------
signature() {
    {
        find "$SNIPPETS" "$INCLUDE" -maxdepth 1 -type f \
            \( -name '*.cpp' -o -name '*.hpp' \) -printf '%T@ %s %p\n' 2>/dev/null
        # Fixtures are inputs too, so editing one reruns the snippet. Generated
        # files under data/*/out/ are deliberately excluded to avoid loops.
        find "$DATA" -mindepth 1 -maxdepth 2 -type f \
            -not -path '*/out/*' -printf '%T@ %s %p\n' 2>/dev/null
    } | sort | md5sum | cut -d' ' -f1
}

clear_screen() {
    if [ -t 1 ]; then
        printf '\033[2J\033[H'
    fi
}

cmd_watch() {
    local target=${1:-} pinned='' last='' sig n
    if [ -n "$target" ]; then
        pinned=$(resolve "$target") || exit 1
    fi

    printf '%s> watch%s  %s%s/, %s/, %s/%s\n' \
        "$B" "$N" "$DIM" "$SNIPPETS" "$INCLUDE" "$DATA" "$N"
    if [ -n "$pinned" ]; then
        printf '  fixed:   %s%s%s\n' "$B" "$pinned" "$N"
    else
        printf '  mode:    most recently modified snippet\n'
    fi
    printf '%s  save a file to rebuild and rerun; Ctrl+C to quit%s\n' "$DIM" "$N"

    while true; do
        sig=$(signature)
        if [ "$sig" != "$last" ]; then
            last=$sig
            clear_screen
            printf '%s> watch%s  %s\n' "$B" "$N" "$(date '+%H:%M:%S')"
            if [ -n "$pinned" ]; then
                run_one "$pinned"
            else
                if n=$(newest); then
                    run_one "$n"
                else
                    err "no snippets yet; create one with: make new NAME=xxx"
                fi
            fi
            printf '\n%swaiting for changes...%s\n' "$DIM" "$N"
        fi
        sleep 0.4
    done
}

# ---- make clean / data / edit / help ------------------------------------
cmd_clean() {
    rm -rf "$BIN" "$CACHE"
    if [ -d "$DATA" ]; then
        # Generated files only: fixtures (everything outside out/) survive.
        find "$DATA" -mindepth 2 -maxdepth 2 -type d -name out -prune -exec rm -rf -- {} +
        find "$DATA" -mindepth 1 -maxdepth 1 -type d -empty -delete
    fi
    ok "removed bin/, .cache/ and generated data/*/out/"
}

# ---- make data -----------------------------------------------------------
# Creates the per-snippet working directory used by file-I/O snippets. The
# snippet needs no header and no path changes: it runs with CWD here.
cmd_data() {
    local name=${1:-} dir
    if [ -z "$name" ]; then
        die 'usage: make data S=NAME'
    fi
    name=$(resolve "$name") || exit 1
    prepare_workdir "$name" || exit 1
    dir=$(workdir_of "$name")
    ok "data dir: $dir"
    printf '  fixtures:  %s/        (commit these)\n' "$dir"
    printf '  generated: %s/out/    (gitignored; make clean wipes it)\n' "$dir"
    printf '  runtime cwd: %s/\n' "$dir"
}

cmd_edit() {
    local t editor
    t=$(resolve "${1:-}") || exit 1
    editor=${EDITOR:-code}
    if ! command -v "$editor" >/dev/null 2>&1; then
        err "editor not found: $editor"
        err "set one first, e.g. EDITOR=vim make edit S=hello"
        exit 1
    fi
    "$editor" "$SNIPPETS/$t.cpp"
}

cmd_help() {
    cat <<'EOF'
test-cpp-code - write small C++ snippets, compile and run them with one command.

  make                    list all snippets (default)
  make list               same as above
  make run S=NAME         compile and run one snippet
  make run                compile and run the most recently modified snippet
  make watch              watch snippets/, rebuild and rerun on every save
  make watch S=NAME       watch only that snippet
  make test               compile + run all snippets, print a pass/fail summary
  make check              compile only (fast syntax check), no execution
  make check S=NAME       compile only one snippet
  make new NAME=NAME      create a snippet (optional: DESC="one line")
  make data S=NAME        create data/NAME/ for a file-I/O snippet
  make edit S=NAME        open a snippet with $EDITOR (default: code)
  make clean              remove bin/, .cache/ and generated data/*/out/
  make commit M="msg"     interactive test + Changelog + commit + push
  make help               this help

S=NAME accepts a snippet name (hello), a file name (hello.cpp) or a path
(snippets/hello.cpp); a unique substring such as S=string also works.

Variables, overridable on the command line:
  STD=c++23        standard. Precedence: command-line STD= > // @std: > c++17
  OPT=-O2          optimization, default -O0
  WARN="-Wall"     warning flags. Default:
                   -Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic
  SAN=1            enable ASan + UBSan
  ARGS="..."       command-line arguments passed to the snippet
  CXX=clang++      use another compiler

Optional metadata in a snippet header:
  // @desc: one-line description
  // @std:  c++23
  // @flags: -pthread

File I/O snippets:
  Each snippet runs with CWD = data/NAME/, created on demand. Put input
  fixtures at the top of that directory and commit them; write generated
  files under out/ only (gitignored). Relative paths just work:
      std::ifstream in("input.txt");
      std::ofstream out("out/result.txt");
  make data S=NAME creates the directory. make clean clears out/ but never
  touches fixtures. Never write to the repository root.

make test feeds every snippet an empty stdin, so a snippet that reads input
must treat EOF as the end and exit; `make run` is for typing input by hand.

Typical workflow:
  make new NAME=string-view DESC="string_view vs string"
  make watch S=string-view     # edit, save, see output
  make test                    # regression across the whole folder

You can also skip make and call the engine directly:
  ./tools/tc.sh run string-view
EOF
}

# ---- Dispatch ------------------------------------------------------------
cmd=${1:-help}
shift || true
case "$cmd" in
    list|ls)          cmd_list ;;
    run)              cmd_run "${1:-}" ;;
    watch|w)          cmd_watch "${1:-}" ;;
    test)             cmd_test ;;
    check|build)      cmd_check "${1:-}" ;;
    new)              cmd_new "${1:-}" "${2:-}" ;;
    data)             cmd_data "${1:-}" ;;
    clean)            cmd_clean ;;
    edit|open)        cmd_edit "${1:-}" ;;
    help|-h|--help)   cmd_help ;;
    *)
        err "unknown command: $cmd"
        cmd_help
        exit 1
        ;;
esac
