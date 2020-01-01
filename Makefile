PREFIX := /usr
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

BLACKARGS := -t py36 aqt tests
ISORTARGS := aqt tests

$(shell mkdir -p .build ../build)

PHONY: all
all: check

# Typescript source
######################

TSDEPS := $(wildcard ts/src/*.ts)
JSDEPS := $(patsubst ts/src/%.ts, web/%.js, $(TSDEPS))

# Building typescript
######################

.build/js: $(TSDEPS)
	(cd ts && npm run build)
	@touch $@

# Checking typescript
######################

.build/ts-fmt: $(TSDEPS)
	(cd ts && npm run check-pretty)
	@touch $@

# Checking
######################

.PHONY: check fix build

check: .build/mypy .build/test .build/fmt .build/imports .build/lint .build/ts-fmt

fix:
	poetry run isort $(ISORTARGS)
	poetry run black $(BLACKARGS)
	(cd ts && npm run pretty)

clean:
	rm -rf .build

# Checking python
######################

LIBPY := ../anki-lib-python

CHECKDEPS := build $(shell find aqt tests -name '*.py')

.build/mypy: $(CHECKDEPS)
	MYPYPATH=$(LIBPY) poetry run mypy aqt
	@touch $@

.build/test: $(CHECKDEPS)
	PYTHONPATH=$(LIBPY) poetry run python -m nose2 --plugin=nose2.plugins.mp -N 16
	@touch $@

.build/lint: $(CHECKDEPS)
	PYTHONPATH=$(LIBPY) poetry run pylint -j 0 --rcfile=.pylintrc -f colorized --extension-pkg-whitelist=PyQt5,ankirspy aqt
	@touch $@

.build/imports: $(CHECKDEPS)
	poetry run isort $(ISORTARGS) --check
	@touch $@

.build/fmt: $(CHECKDEPS)
	poetry run black --check $(BLACKARGS)
	@touch $@

# Building
######################

.PHONY: build

# we only want the wheel when building, but passing -f wheel to poetry
# breaks the inclusion of files listed in pyproject.toml
build: $(CHECKDEPS) .build/ui .build/js
	rm -rf dist
	poetry build
	rsync -a dist/*.whl ../build/

.build/dev-deps: pyproject.toml
	poetry install --no-root
	@touch $@

.build/ui: .build/dev-deps $(shell find designer -type f)
	./tools/build_ui.sh
	@touch $@
