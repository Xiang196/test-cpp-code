#!/usr/bin/env bash
# ============================================================================
# commit.sh - interactive test/commit helper with a Changelog.md workflow.
#
#   ./tools/commit.sh                    interactive: message, changelog,
#                                        test, stage, commit, push prompt
#   ./tools/commit.sh -m "feat: ..."     skip the message prompt
#   ./tools/commit.sh -m "..." -y        non-interactive with defaults
#   ./tools/commit.sh --no-changelog     leave Changelog.md alone
#   ./tools/commit.sh --tracked-only     stage tracked changes only
#   ./tools/commit.sh --no-test          skip make test
#   ./tools/commit.sh --no-push          commit locally only
#
# Non-interactive example:
#   ./tools/commit.sh -m "fix: ..." -y --no-push \
#       --changelog-category Fixed \
#       --changelog-entry "Fix ..."
#
# Exit codes: 0 ok, 1 usage or git error, 2 tests failed, 130 cancelled.
# ============================================================================
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1

CHANGELOG=Changelog.md

# ---- Colors (plain ASCII output; color only on a terminal) -----------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
else
    B=''; G=''; Y=''; R=''; N=''
fi

say()     { printf '%s\n' "$*"; }
section() { printf '\n%s== %s ==%s\n' "$B" "$*" "$N"; }
ok()      { printf '%s[ok]%s %s\n' "$G" "$N" "$*"; }
warn()    { printf '%s[!]%s %s\n' "$Y" "$N" "$*"; }
die()     { printf '%sERROR:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
abort()   { printf '\n'; warn "cancelled; nothing was committed"; exit 130; }

trim() {
    local s=${1-}
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s' "$s"
}

# Read one line into REPLY. When stdin is a pipe (tests, automation), the
# terminal does not echo the newline, so add one to keep the log readable.
read_reply() {
    IFS= read -r REPLY || abort
    [ -t 0 ] || printf '\n'
}

ask_yes_no() {
    local prompt=$1 default=${2:-y} suffix answer
    if [ "$default" = y ]; then suffix='[Y/n]'; else suffix='[y/N]'; fi
    while true; do
        printf '  %s %s ' "$prompt" "$suffix"
        read_reply
        answer=$REPLY
        answer=${answer:-$default}
        case ${answer,,} in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) warn "please answer y or n" ;;
        esac
    done
}

tmp_changelog=''
cleanup() {
    if [ -n "$tmp_changelog" ]; then
        rm -f -- "$tmp_changelog"
    fi
}
trap cleanup EXIT

# True when the [Unreleased] section already contains this exact bullet.
changelog_has_entry() {
    local entry=$1
    TC_ENTRY="$entry" awk '
        /^## \[Unreleased\]/ { in_unreleased = 1; next }
        in_unreleased && /^## \[/ { exit }
        in_unreleased && $0 == "- " ENVIRON["TC_ENTRY"] { found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "$CHANGELOG"
}

# ---- Changelog helper ------------------------------------------------------
# Appends one bullet to the requested category inside [Unreleased], creating
# the category or the whole section when needed. The file is rewritten only
# after awk succeeds, so a parse failure never leaves a truncated changelog.
changelog_add() {
    local category=$1 entry=$2 tmp
    mkdir -p .cache
    tmp=".cache/changelog.$$.tmp"
    tmp_changelog=$tmp

    if ! TC_CAT="$category" TC_ENTRY="$entry" awk '
        BEGIN {
            cat = ENVIRON["TC_CAT"]
            entry = ENVIRON["TC_ENTRY"]
            n = 0
        }
        { line[++n] = $0 }
        END {
            u = 0
            for (i = 1; i <= n; i++)
                if (line[i] ~ /^## \[Unreleased\]/) { u = i; break }
            if (!u) exit 2

            ub = n
            for (i = u + 1; i <= n; i++)
                if (line[i] ~ /^## \[/) { ub = i - 1; break }

            c = 0
            for (i = u + 1; i <= ub; i++)
                if (line[i] == "### " cat) { c = i; break }

            if (c) {
                ce = ub
                for (i = c + 1; i <= ub; i++)
                    if (line[i] ~ /^### /) { ce = i - 1; break }

                last = c
                for (i = c + 1; i <= ce; i++)
                    if (line[i] !~ /^[[:space:]]*$/) last = i

                if (last == c) {
                    for (i = 1; i <= c; i++) print line[i]
                    print ""
                    print "- " entry
                    print ""
                    j = c + 1
                    while (j <= n && line[j] ~ /^[[:space:]]*$/) j++
                    for (i = j; i <= n; i++) print line[i]
                } else {
                    for (i = 1; i <= last; i++) print line[i]
                    print "- " entry
                    for (i = last + 1; i <= n; i++) print line[i]
                }
            } else {
                last = u
                for (i = u + 1; i <= ub; i++)
                    if (line[i] !~ /^[[:space:]]*$/) last = i

                for (i = 1; i <= last; i++) print line[i]
                print ""
                print "### " cat
                print ""
                print "- " entry
                print ""
                j = last + 1
                while (j <= n && line[j] ~ /^[[:space:]]*$/) j++
                for (i = j; i <= n; i++) print line[i]
            }
        }
    ' "$CHANGELOG" >"$tmp"; then
        rm -f -- "$tmp"
        tmp_changelog=''
        return 1
    fi

    chmod --reference="$CHANGELOG" -- "$tmp" 2>/dev/null ||
        chmod 644 -- "$tmp" ||
        { rm -f -- "$tmp"; tmp_changelog=''; return 1; }

    if ! mv -- "$tmp" "$CHANGELOG"; then
        rm -f -- "$tmp"
        tmp_changelog=''
        return 1
    fi
    tmp_changelog=''

    changelog_has_entry "$entry"
}

usage() {
    cat <<'EOF'
usage: ./tools/commit.sh [options] [message]

Interactive by default. Prompts for a commit message and a Changelog.md
entry, runs make test, stages changes, commits, and offers to push.

Options:
  -m, --message MSG           use MSG instead of asking for a message
      --changelog-category C  Added, Changed, Fixed, Removed, Deprecated,
                              or Security (default: guessed from the message)
      --changelog-entry TEXT  one-line changelog entry
      --no-changelog          do not modify Changelog.md
      --tracked-only          stage tracked changes only (leave untracked)
      --no-test               skip make test
      --no-push               commit locally, do not push
  -y, --yes                   accept confirmations and changelog defaults
  -h, --help                  this help

Examples:
  ./tools/commit.sh
  ./tools/commit.sh -m "feat: add string trim" --no-push
  ./tools/commit.sh -m "fix: ..." -y --no-push \
      --changelog-category Fixed --changelog-entry "Fix ..."
EOF
}

# ---- Arguments -------------------------------------------------------------
msg=''
run_tests=1
do_push=1
update_changelog=1
tracked_only=0
assume_yes=0
changelog_cat=''
changelog_entry=''

while [ $# -gt 0 ]; do
    case $1 in
        -m|--message)
            [ $# -ge 2 ] || die "$1 needs a value"
            msg=$2
            shift 2
            ;;
        --changelog-category)
            [ $# -ge 2 ] || die "$1 needs a value"
            changelog_cat=$2
            shift 2
            ;;
        --changelog-entry)
            [ $# -ge 2 ] || die "$1 needs a value"
            changelog_entry=$2
            shift 2
            ;;
        --no-changelog)
            update_changelog=0
            shift
            ;;
        --tracked-only)
            tracked_only=1
            shift
            ;;
        --no-test)
            run_tests=0
            shift
            ;;
        --no-push)
            do_push=0
            shift
            ;;
        -y|--yes)
            assume_yes=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        '')
            shift
            ;;
        -*)
            die "unknown option: $1 (try --help)"
            ;;
        *)
            [ -z "$msg" ] || die "unexpected argument: $1"
            msg=$1
            shift
            ;;
    esac
done

msg=$(trim "$msg")
case $msg in
    *$'\n'*) die "the commit message must be one line" ;;
esac

# ---- Repository and working tree ------------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "not inside a git repository"
fi

status=$(git status --porcelain)
if [ -z "$status" ]; then
    ok "nothing to commit (working tree clean)"
    exit 0
fi

staged=$(git diff --cached --name-only | wc -l | tr -d ' ')
unstaged=$(git diff --name-only | wc -l | tr -d ' ')
untracked=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')

section "Changes"
git status --short
say ""
say "  staged: $staged, modified: $unstaged, untracked: $untracked"

if [ "$tracked_only" -eq 1 ]; then
    stage_mode=tracked
elif [ "$untracked" -eq 0 ]; then
    stage_mode=all
elif [ "$assume_yes" -eq 1 ]; then
    stage_mode=all
elif ask_yes_no "Stage all changes, including untracked files?" y; then
    stage_mode=all
else
    stage_mode=tracked
    say "  tracked changes only; untracked files stay untracked"
fi

if [ "$stage_mode" = tracked ] && [ "$staged" -eq 0 ] && [ "$unstaged" -eq 0 ]; then
    die "no tracked changes to commit; choose all changes or stage files with git add"
fi

# ---- Commit message --------------------------------------------------------
if [ -z "$msg" ]; then
    section "Commit message"
    say "  Convention: type: short summary"
    say "  Types: feat, fix, docs, refactor, perf, test, chore"
    while true; do
        printf '  > '
        read_reply
        msg=$(trim "$REPLY")
        [ -n "$msg" ] && break
        warn "message cannot be empty"
    done
else
    section "Commit message"
    say "  $msg"
fi

if [ "${#msg}" -gt 72 ]; then
    warn "message is ${#msg} characters; 72 or fewer reads better"
fi

# ---- Changelog entry -------------------------------------------------------
category=''
changelog_duplicate=0
if [ "$update_changelog" -eq 1 ]; then
    [ -f "$CHANGELOG" ] || die "$CHANGELOG not found (use --no-changelog to skip)"
    grep -q '^## \[Unreleased\]' -- "$CHANGELOG" ||
        die "$CHANGELOG has no '## [Unreleased]' section"

    categories=(Added Changed Fixed Removed Deprecated Security)

    # Guess the category from Conventional Commits type.
    cat_num=2
    case ${msg%%:*} in
        feat|feature) cat_num=1 ;;
        fix|bugfix|hotfix) cat_num=3 ;;
        remove|revert) cat_num=4 ;;
    esac

    if [ -n "$changelog_cat" ]; then
        case ${changelog_cat,,} in
            added)      cat_num=1 ;;
            changed)    cat_num=2 ;;
            fixed)      cat_num=3 ;;
            removed)    cat_num=4 ;;
            deprecated) cat_num=5 ;;
            security)   cat_num=6 ;;
            *)
                die "unknown changelog category: $changelog_cat"
                ;;
        esac
    fi

    # Default entry: commit subject with the Conventional Commits prefix
    # removed, so "fix: stop the crash" becomes "stop the crash".
    default_entry=$msg
    case ${msg%%:*} in
        feat|feature|fix|bugfix|hotfix|docs|refactor|perf|test|chore|build|ci|style|remove|revert)
            default_entry=$(trim "${msg#*:}")
            ;;
    esac
    [ -n "$default_entry" ] || default_entry=$msg

    if [ "$assume_yes" -eq 0 ]; then
        section "Changelog"
        say "  Add one bullet under [Unreleased] in $CHANGELOG."
    fi

    if [ "$assume_yes" -eq 0 ] && [ -z "$changelog_cat" ]; then
        i=1
        for name in "${categories[@]}"; do
            mark=''
            [ "$i" -eq "$cat_num" ] && mark='  <- default'
            printf '    %d) %s%s\n' "$i" "$name" "$mark"
            i=$((i + 1))
        done
        while true; do
            printf '  Category [%d]: ' "$cat_num"
            read_reply
            choice=$(trim "$REPLY")
            choice=${choice:-$cat_num}
            case $choice in
                [1-6]) cat_num=$choice; break ;;
                *) warn "choose a number from 1 to 6" ;;
            esac
        done
    fi

    category=${categories[$((cat_num - 1))]}

    if [ -z "$changelog_entry" ]; then
        if [ "$assume_yes" -eq 1 ]; then
            changelog_entry=$default_entry
        else
            while true; do
                printf '  Entry [%s]: ' "$default_entry"
                read_reply
                changelog_entry=${REPLY:-$default_entry}
                changelog_entry=$(trim "$changelog_entry")
                [ -n "$changelog_entry" ] && break
                warn "entry cannot be empty (use --no-changelog to skip)"
            done
        fi
    fi

    changelog_entry=$(trim "$changelog_entry")
    changelog_entry=${changelog_entry#- }
    changelog_entry=${changelog_entry#-}
    changelog_entry=$(trim "$changelog_entry")

    [ -n "$changelog_entry" ] ||
        die "changelog entry is empty (use --no-changelog to skip)"
    case $changelog_entry in
        *$'\n'*) die "--changelog-entry must be one line" ;;
    esac
    if printf '%s' "$changelog_entry" | LC_ALL=C grep -q '[^[:print:]]'; then
        die "Changelog.md must stay ASCII; use an English entry"
    fi

    if changelog_has_entry "$changelog_entry"; then
        changelog_duplicate=1
        warn "entry already exists in $CHANGELOG; not adding it twice"
    fi
else
    if [ -n "$changelog_cat" ] || [ -n "$changelog_entry" ]; then
        warn "--no-changelog: ignoring changelog options"
    fi
fi

# ---- Preview and confirmation ---------------------------------------------
section "Ready"
say "  message:   $msg"
if [ "$update_changelog" -eq 1 ]; then
    if [ "$changelog_duplicate" -eq 1 ]; then
        say "  changelog: already present in ### $category"
    else
        say "  changelog: ### $category"
        say "             - $changelog_entry"
    fi
else
    say "  changelog: skipped"
fi
say "  stage:     $stage_mode"
if [ "$run_tests" -eq 1 ]; then
    say "  tests:     make test"
else
    say "  tests:     skipped"
fi

if [ "$assume_yes" -eq 0 ]; then
    ask_yes_no "Continue?" y || {
        say "  aborted; nothing was staged or committed"
        exit 1
    }
fi

# ---- Tests -----------------------------------------------------------------
if [ "$run_tests" -eq 1 ]; then
    section "Tests"
    say "  make test"
    # A nested `make` inherits STD/TC_FORCE_STD from the outer `make commit`
    # recipe; that would force c++17 over a snippet's `// @std:` header.
    # Unset both so the gate tests the snippets with their declared standard.
    if ! (unset STD TC_FORCE_STD; make test); then
        warn "make test failed; nothing was committed"
        exit 2
    fi
else
    warn "tests skipped (--no-test)"
fi

# ---- Update Changelog.md ---------------------------------------------------
if [ "$update_changelog" -eq 1 ] && [ "$changelog_duplicate" -eq 0 ]; then
    section "Changelog"
    if changelog_add "$category" "$changelog_entry"; then
        ok "added '$changelog_entry' under ### $category"
    else
        die "could not update $CHANGELOG"
    fi
fi

# ---- Stage -----------------------------------------------------------------
section "Stage"
if [ "$stage_mode" = all ]; then
    git add -A
else
    git add -u
fi
git --no-pager diff --cached --stat
if git diff --cached --quiet; then
    die "nothing staged; aborting"
fi

# ---- Commit ----------------------------------------------------------------
section "Commit"
if ! git commit -m "$msg"; then
    die "git commit failed; changes remain staged"
fi
ok "committed $(git rev-parse --short HEAD)"

# ---- Push ------------------------------------------------------------------
if [ "$do_push" -eq 0 ]; then
    say ""
    say "  push skipped (--no-push); run: git push when ready"
else
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ -z "$branch" ] || [ "$branch" = HEAD ]; then
        warn "detached HEAD; push skipped"
    else
        push_now=0
        if [ "$assume_yes" -eq 1 ]; then
            push_now=1
        elif ask_yes_no "Push to origin/$branch?" y; then
            push_now=1
        fi
        if [ "$push_now" -eq 1 ]; then
            section "Push"
            if ! git push -u origin "$branch"; then
                warn "push failed; the commit is local"
                exit 1
            fi
            ok "pushed origin/$branch"
        else
            say "  not pushed; run: git push when ready"
        fi
    fi
fi

echo
git --no-pager log --oneline -3
git status --short --branch
