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

PHONY: all
all: check

.build/dev-deps: pyproject.toml
	poetry install --no-root
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

CHECKDEPS := .build/dev-deps .build/py-proto $(shell find anki tests -name '*.py' | grep -v buildhash.py)

.build/mypy: $(CHECKDEPS)
	mypy anki
	@touch $@

.build/test: $(CHECKDEPS)
	python -m nose2 --plugin=nose2.plugins.mp -N 16
	@touch $@

.build/lint: $(CHECKDEPS)
	pylint -j 0 --rcfile=.pylintrc -f colorized --extension-pkg-whitelist=ankirspy anki
	@touch $@

.build/imports: $(CHECKDEPS)
	isort $(ISORTARGS) --check
	@touch $@

.build/fmt: $(CHECKDEPS)
	black --check $(BLACKARGS)
	@touch $@

# Building
######################

.PHONY: build install

# we only want the wheel when building, but passing -f wheel to poetry
# breaks the inclusion of files listed in pyproject.toml
build: $(CHECKDEPS)
	rm -rf dist
	echo "build='$$(git rev-parse --short HEAD)'" > anki/buildhash.py
	poetry build

PROTODEPS := $(wildcard ../anki-proto/*.proto)

.build/py-proto: .build/dev-deps $(PROTODEPS)
	protoc --proto_path=../anki-proto --python_out=anki --mypy_out=anki $(PROTODEPS)
	@touch $@

install: build
	pip install --force-reinstall dist/*.whl
