# ============================================================================
# test-cpp-code - write small C++ snippets, compile and run them with one command.
#
#   make                    list all snippets
#   make run S=NAME         compile and run (no S = most recently modified)
#   make watch              rebuild and rerun on every save
#   make test               compile + run everything, print a summary
#   make wiki               publish wiki/ to the GitHub wiki repository
#
# Full usage: make help
#
# File-I/O snippets run with CWD = data/NAME/ (created on demand). Input
# fixtures are committed there; generated files go under data/NAME/out/,
# which is gitignored and wiped by make clean.
#
# Defaults: -std=c++17 -O0
#           -Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic
#
# This Makefile only holds shortcuts and variables; the real logic lives in
# tools/tc.sh, so adding a feature means editing one file.
# ============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := list

# ---- Overridable variables: make run S=foo STD=c++23 SAN=1 ----------------
CXX      ?= g++
# STD is intentionally not defaulted here: the default c++17 lives in
# tools/tc.sh. That way only an explicit command-line STD= overrides the
# // @std: header inside a snippet; otherwise the header wins.
STD      ?=
OPT      ?= -O0
WARN     ?= -Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic
CXXFLAGS ?=
SAN      ?= 0
S        ?=
ARGS     ?=
M        ?=

# Did the user pass STD= on the command line (or via the environment)?
# If so, it overrides the snippet's // @std: header.
TC_FORCE_STD := $(if $(filter command line environment,$(origin STD)),1,0)

export CXX STD OPT WARN CXXFLAGS SAN ARGS TC_FORCE_STD

TC := ./tools/tc.sh
BASH ?= bash

.PHONY: list ls run watch test check dates new data clean edit commit wiki help

list:                 # list all snippets (default target)
	@$(BASH) $(TC) list

ls: list

run:                  # compile and run; make run S=xxx, no S = most recent
	@$(BASH) $(TC) run $(S)

watch:                # rebuild and rerun on save; make watch S=xxx for one
	@$(BASH) $(TC) watch $(S)

test:                 # compile + run everything, print pass/fail summary
	@$(BASH) $(TC) test

check:                # compile only; make check S=xxx for one snippet
	@$(BASH) $(TC) check $(S)

dates:                # list snippets by creation date; validate @created
	@$(BASH) $(TC) dates

new:                  # create a snippet: make new NAME=xxx DESC="one line"
	@$(BASH) $(TC) new "$(NAME)" "$(DESC)"

data:                 # create data/NAME/ for a file-I/O snippet
	@$(BASH) $(TC) data $(S)

edit:                 # open a snippet with $EDITOR: make edit S=xxx
	@$(BASH) $(TC) edit $(S)

clean:                # remove bin/, .cache/ and generated data/*/out/
	@$(BASH) $(TC) clean

commit:               # interactive commit + changelog: make commit [M="message"]
	@$(BASH) ./tools/commit.sh "$(M)"

wiki:                 # publish wiki/ to the wiki clone (M="message" optional)
	@$(BASH) ./tools/wiki.sh "$(M)"

help:                 # show full help
	@$(BASH) $(TC) help
