#!/usr/bin/env bash
# ============================================================================
# wiki.sh - publish the Markdown under wiki/ to the GitHub wiki repository.
#
#   wiki/ is the source of truth. This script copies it to a separate clone of
#   <repo>.wiki.git (outside this repository by default), commits there, and
#   pushes. The main repository is never modified.
#
#   ./tools/wiki.sh                  sync, commit, push
#   ./tools/wiki.sh -m "msg"         use a custom commit message
#   ./tools/wiki.sh --dry-run        show the diff, change nothing
#   ./tools/wiki.sh --no-push        commit locally, do not push
#   ./tools/wiki.sh --no-pull        do not fast-forward the clone first
#   ./tools/wiki.sh --delete         remove pages deleted from wiki/
#
#   WIKI_DIR=/path/to/clone  override the clone location
#   WIKI_URL=git@...         remote to clone when WIKI_DIR does not exist
#
# Exit codes: 0 ok (also when there is nothing to publish), 1 usage/git error.
# ============================================================================
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT" || exit 1

SRC=wiki
WIKI_DIR=${WIKI_DIR:-}
WIKI_URL=${WIKI_URL:-}

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

usage() {
    cat <<'EOF'
usage: ./tools/wiki.sh [options]

Publishes wiki/ to the separate GitHub wiki repository: copy, commit, push.

Options:
  -m, --message MSG   commit message
                      (default: docs: sync wiki from <repo>@<sha>)
      --dry-run       show the diff only; change nothing
      --no-push       commit locally, do not push
      --no-pull       do not fast-forward the wiki clone first
      --delete        delete wiki pages that no longer exist under wiki/
  -h, --help          this help

Environment:
  WIKI_DIR   wiki clone location (default: ../<repo>.wiki)
  WIKI_URL   remote used when the clone does not exist
             (default: the origin URL with .wiki.git appended)

Examples:
  ./tools/wiki.sh
  ./tools/wiki.sh --dry-run
  ./tools/wiki.sh --no-push -m "docs: refresh the make guide"
  WIKI_DIR=~/src/github/test-cpp-code.wiki ./tools/wiki.sh
EOF
}

# ---- Arguments -------------------------------------------------------------
msg=''
do_push=1
do_pull=1
do_delete=0
dry_run=0

while [ $# -gt 0 ]; do
    case $1 in
        -m|--message)
            [ $# -ge 2 ] || die "$1 needs a value"
            msg=$2
            shift 2
            ;;
        --dry-run|-n)
            dry_run=1
            shift
            ;;
        --no-push)
            do_push=0
            shift
            ;;
        --no-pull)
            do_pull=0
            shift
            ;;
        --delete)
            do_delete=1
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

# ---- Locate the source and the clone --------------------------------------
[ -d "$SRC" ] || die "missing source directory: $SRC/"
src_count=$(find "$SRC" -maxdepth 1 -type f ! -name '.*' | wc -l)
[ "$src_count" -gt 0 ] || die "no files in $SRC/"

origin_url=$(git remote get-url origin 2>/dev/null || true)
origin_url=${origin_url%/}
repo_name=''
if [ -n "$origin_url" ]; then
    repo_name=$(basename -- "${origin_url%.git}")
fi
[ -n "$repo_name" ] || repo_name=$(basename -- "$ROOT")

if [ -z "$WIKI_DIR" ]; then
    WIKI_DIR="$ROOT/../$repo_name.wiki"
fi
case $WIKI_DIR in
    /*) ;;
    *) WIKI_DIR="$ROOT/$WIKI_DIR" ;;
esac

if [ -z "$WIKI_URL" ] && [ -n "$origin_url" ]; then
    WIKI_URL="${origin_url%.git}.wiki.git"
fi

say "  source:  $ROOT/$SRC/"
say "  clone:   $WIKI_DIR"

# ---- Clone on demand ------------------------------------------------------
if [ ! -e "$WIKI_DIR" ]; then
    [ "$dry_run" -eq 0 ] ||
        die "wiki clone not found: $WIKI_DIR (run without --dry-run to clone)"
    [ -n "$WIKI_URL" ] ||
        die "wiki clone not found: $WIKI_DIR (set WIKI_DIR or WIKI_URL)"
    section "Clone"
    say "  $WIKI_URL"
    git clone --quiet "$WIKI_URL" "$WIKI_DIR" || die "git clone failed: $WIKI_URL"
fi

git -C "$WIKI_DIR" rev-parse --git-dir >/dev/null 2>&1 ||
    die "not a git clone: $WIKI_DIR"
branch=$(git -C "$WIKI_DIR" symbolic-ref --short HEAD 2>/dev/null || true)
[ -n "$branch" ] || die "wiki clone is on a detached HEAD: $WIKI_DIR"

if [ -n "$(git -C "$WIKI_DIR" status --porcelain)" ]; then
    die "wiki clone has uncommitted changes; clean it first: $WIKI_DIR"
fi

# ---- Dry run: show the diff without writing ------------------------------
if [ "$dry_run" -eq 1 ]; then
    section "Diff"
    if diff -ru --exclude=.git "$SRC" "$WIKI_DIR"; then
        ok "wiki is already up to date"
    else
        say ""
        warn "dry run: nothing was copied, committed, or pushed"
    fi
    exit 0
fi

# ---- Fast-forward the clone ----------------------------------------------
if [ "$do_pull" -eq 1 ]; then
    if git -C "$WIKI_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' \
        >/dev/null 2>&1; then
        section "Pull"
        say "  fast-forward $WIKI_DIR"
        git -C "$WIKI_DIR" pull --ff-only --quiet ||
            die "cannot fast-forward; resolve $WIKI_DIR (or use --no-pull)"
    else
        warn "wiki clone has no upstream; skipping pull"
    fi
fi

# ---- Copy the source of truth into the clone -----------------------------
section "Sync"
find "$SRC" -maxdepth 1 -type f ! -name '.*' \
    -exec cp -a -t "$WIKI_DIR" -- {} + || die "copy failed: $SRC/ -> $WIKI_DIR"
ok "copied $src_count file(s)"

# Pages removed from wiki/ are only deleted with --delete; otherwise report
# them so a rename does not silently leave a stale page in the wiki repo.
extras=()
while IFS= read -r -d '' f; do
    base=${f##*/}
    [ -e "$SRC/$base" ] || extras+=("$base")
done < <(find "$WIKI_DIR" -maxdepth 1 -type f ! -name '.*' -print0)

if [ ${#extras[@]} -gt 0 ]; then
    if [ "$do_delete" -eq 1 ]; then
        for base in "${extras[@]}"; do
            rm -f -- "$WIKI_DIR/$base"
        done
        ok "deleted ${#extras[@]} stale page(s): ${extras[*]}"
    else
        warn "pages in the wiki clone but not in $SRC/: ${extras[*]}"
        warn "use --delete to remove them"
    fi
fi

git -C "$WIKI_DIR" add -A

if git -C "$WIKI_DIR" diff --cached --quiet; then
    ok "wiki is already up to date"
    exit 0
fi

say ""
git -C "$WIKI_DIR" --no-pager diff --cached --stat

if [ -n "$(git -C "$ROOT" status --porcelain -- "$SRC")" ]; then
    warn "$SRC/ has uncommitted changes; publishing the working tree"
fi

# ---- Commit ---------------------------------------------------------------
if [ -z "$msg" ]; then
    sha=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || printf 'unknown')
    if [ -n "$(git -C "$ROOT" status --porcelain -- "$SRC")" ]; then
        msg="docs: sync wiki from $repo_name@$sha (working tree)"
    else
        msg="docs: sync wiki from $repo_name@$sha"
    fi
fi

section "Commit"
say "  $msg"
git -C "$WIKI_DIR" commit --quiet -m "$msg" ||
    die "git commit failed in $WIKI_DIR"
ok "committed $(git -C "$WIKI_DIR" rev-parse --short HEAD)"

# ---- Push -----------------------------------------------------------------
if [ "$do_push" -eq 0 ]; then
    say ""
    say "  push skipped (--no-push); commit is local in $WIKI_DIR"
    exit 0
fi

section "Push"
say "  origin/$branch"
if ! git -C "$WIKI_DIR" push origin "HEAD:refs/heads/$branch"; then
    warn "push failed; resolve $WIKI_DIR and rerun, or push manually:"
    warn "  git -C $WIKI_DIR push origin HEAD:$branch"
    exit 1
fi
ok "pushed origin/$branch"

echo
git -C "$WIKI_DIR" --no-pager log --oneline -1
