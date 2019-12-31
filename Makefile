PREFIX := /usr
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
RUNARGS :=
.SUFFIXES:
BLACKARGS := -t py36 anki tests
ISORTARGS := anki tests

$(shell mkdir -p .build)

all: check

RUNREQS := .build/py-run-deps

# Python prerequisites
######################

.build/py-run-deps: requirements.txt
	pip install -r $<
	@touch $@

.build/py-check-reqs: requirements.check .build/py-run-deps
	pip install -r $<
	@touch $@

# Checking
######################

.PHONY: check fix build

check: .build/mypy .build/test .build/fmt .build/imports .build/lint

fix:
	isort $(ISORTARGS)
	black $(BLACKARGS)

clean:
	rm -rf .build

# Checking python
######################

PYCHECKDEPS := $(BUILDDEPS) .build/py-check-reqs $(shell find anki -name '*.py' | grep -v buildhash.py)
PYTESTDEPS := $(wildcard tests/*.py)

.build/mypy: $(PYCHECKDEPS)
	mypy anki
	@touch $@

.build/test: $(PYCHECKDEPS) $(PYTESTDEPS)
	python -m nose2 --plugin=nose2.plugins.mp -N 16
	@touch $@

.build/lint: $(PYCHECKDEPS)
	pylint -j 0 --rcfile=.pylintrc -f colorized --extension-pkg-whitelist=ankirspy anki
	@touch $@

.build/imports: $(PYCHECKDEPS) $(PYTESTDEPS)
	isort $(ISORTARGS) --check
	@touch $@

.build/fmt: $(PYCHECKDEPS) $(PYTESTDEPS)
	black --check $(BLACKARGS)
	@touch $@
