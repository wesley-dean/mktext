# Makefile
#
# Canonical development and automation entry points for mktext.
# The sourceable mktext.bash file is both maintained source and release artifact;
# no generated distribution copy is required by the initial architecture.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

LIBRARY := mktext.bash
TESTS_DIR := tests
TEST_SCRIPTS := $(TESTS_DIR)/*.bats
VENDOR_DIR := vendor
DOXYGEN_BASH_FILTER := $(VENDOR_DIR)/doxygen-bash.awk
DOXYGEN_BASH_FILTER_URL := https://raw.githubusercontent.com/wesley-dean/bash-doxygen/refs/heads/main/doxygen-bash.awk
REFERENCE_DOC_DIR := doc/reference

.PHONY: all check clean docs docs-clean format test

all: check test

##
# Validate the maintained Bash library with the shell parser and ShellCheck.
#
check:
	bash -n "$(LIBRARY)"
	shellcheck "$(LIBRARY)"

##
# Format the maintained Bash library using the repository's canonical formatter.
#
format:
	shfmt -w -i 2 -ci "$(LIBRARY)"

##
# Run the public behavior suite against the sourceable release artifact.
#
test:
	bats $(TEST_SCRIPTS)

##
# Download the Bash Doxygen filter used to preprocess shell source files.
#
$(DOXYGEN_BASH_FILTER):
	mkdir -p "$(VENDOR_DIR)"
	curl -fsSL "$(DOXYGEN_BASH_FILTER_URL)" -o "$@.tmp"
	chmod 0755 "$@.tmp"
	mv "$@.tmp" "$@"

##
# Remove generated reference documentation while preserving its README sentinel.
#
docs-clean:
	@if [[ -d "$(REFERENCE_DOC_DIR)" ]]; then \
		find "$(REFERENCE_DOC_DIR)" -mindepth 1 ! -name README.md -exec rm -rf {} +; \
	fi

##
# Generate browsable Doxygen reference documentation.
#
docs: docs-clean $(DOXYGEN_BASH_FILTER)
	mkdir -p "$(REFERENCE_DOC_DIR)"
	doxygen Doxyfile

clean: docs-clean
	$(RM) -f "$(DOXYGEN_BASH_FILTER)"
	-rmdir "$(VENDOR_DIR)" >/dev/null 2>&1
