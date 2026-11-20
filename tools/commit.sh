#!/usr/bin/env bash
# ============================================================================
# commit.sh - run the test suite, stage everything, commit, push.
#
#   ./tools/commit.sh "message"
#   ./tools/commit.sh -m "message"
#   ./tools/commit.sh --no-test "message"     skip `make test`
#   ./tools/commit.sh --no-push "message"     commit only, do not push
#
# The test gate matters because the default flags include -Werror: any warning
# anywhere means nothing gets committed.
#
# Exit codes: 0 ok, 1 usage or git error, 2 tests failed.
# ============================================================================
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1

usage() {
    cat <<'EOF'
usage: ./tools/commit.sh [--no-test] [--no-push] [-m "message"]
       ./tools/commit.sh "message"
EOF
}

msg=''
run_tests=1
do_push=1
while [ $# -gt 0 ]; do
    case $1 in
        -m|--message)
            if [ $# -lt 2 ]; then
                echo "ERROR: $1 needs a message" >&2
                usage >&2
                exit 1
            fi
            msg=$2
            shift 2
            ;;
        --no-test)
            run_tests=0
            shift
            ;;
        --no-push)
            do_push=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "ERROR: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            msg=$1
            shift
            ;;
    esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: not inside a git repository" >&2
    exit 1
fi

if [ -z "$(git status --porcelain)" ]; then
    echo "nothing to commit (working tree clean)"
    exit 0
fi

if [ -z "$msg" ]; then
    echo "ERROR: commit message is required" >&2
    usage >&2
    exit 1
fi

if [ "$run_tests" -eq 1 ]; then
    echo "== make test =="
    if ! make test; then
        echo "ERROR: make test failed, nothing was committed" >&2
        exit 2
    fi
    echo
fi

git add -A
echo "== staged =="
git --no-pager diff --cached --stat

git commit -m "$msg"
echo

if [ "$do_push" -eq 1 ]; then
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$branch" = "HEAD" ]; then
        echo "ERROR: detached HEAD, cannot push" >&2
        exit 1
    fi
    echo "== git push origin $branch =="
    git push -u origin "$branch"
    echo
fi

git --no-pager log --oneline -3
git status --short --branch
