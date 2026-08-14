#!/usr/bin/env bash

# Minimal runtime-compatibility checks that intentionally depend only on Bash.
# This file is executed under the project's minimum supported Bash release in
# CI, where Bats and the rest of the development toolchain are not required.

set -u
set -o pipefail

failures=0

check_equal() {
  local expected
  local actual
  local label

  expected="$1"
  actual="$2"
  label="$3"

  if [[ ${actual} == "${expected}" ]]; then
    return 0
  fi

  printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' \
    "${label}" "${expected}" "${actual}" >&2
  failures=$((failures + 1))
}

check_status() {
  local expected
  local actual
  local label

  expected="$1"
  actual="$2"
  label="$3"

  if [[ ${actual} -eq ${expected} ]]; then
    return 0
  fi

  printf 'FAIL: %s\n  expected status: %s\n  actual status:   %s\n' \
    "${label}" "${expected}" "${actual}" >&2
  failures=$((failures + 1))
}

capture() {
  local __compat_output_name
  local __compat_status_name
  local __compat_value
  local __compat_status

  __compat_output_name="$1"
  __compat_status_name="$2"
  shift 2

  if __compat_value="$("$@")"; then
    __compat_status=0
  else
    __compat_status=$?
  fi

  printf -v "${__compat_output_name}" '%s' "${__compat_value}"
  printf -v "${__compat_status_name}" '%s' "${__compat_status}"
}

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
  printf 'FAIL: compatibility harness requires Bash 4.3 or newer; found %s\n' \
    "${BASH_VERSION}" >&2
  exit 1
fi

MKTEXT_LIBRARY="${MKTEXT_LIBRARY:-./src/mktext.bash}"

# The compatibility target is selected dynamically so the same harness can
# exercise maintained source and the generated distribution artifact.
# shellcheck disable=SC1090
source "${MKTEXT_LIBRARY}"

output=''
status=0
capture output status mktext --help
check_status 0 "${status}" 'help status'
if [[ ${output} != Usage:* || ${output} != *'mktext version'* ]]; then
  printf 'FAIL: help output did not contain the expected usage surface\n' >&2
  failures=$((failures + 1))
fi
help_output="${output}"

output=''
status=0
capture output status mktext --version
check_status 0 "${status}" 'version status'
if [[ ${output} != mktext\ *$'\n'build_date=* || ${output} != *$'\n'commit=* ]]; then
  printf 'FAIL: version output did not contain three metadata lines\n' >&2
  failures=$((failures + 1))
fi
version_output="${output}"

if mktext foobar >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
check_status 2 "${status}" 'unknown operation status'

# Generated distribution artifacts are executable as well as sourceable.  The
# maintained source normally lacks executable mode, so these checks apply only
# when the selected target advertises direct execution.
if [[ -x ${MKTEXT_LIBRARY} ]]; then
  first_line=''
  IFS= read -r first_line <"${MKTEXT_LIBRARY}" || :
  check_equal '#!/usr/bin/env bash' "${first_line}" 'distribution interpreter directive'

  output=''
  status=0
  capture output status "${MKTEXT_LIBRARY}" --help
  check_status 0 "${status}" 'direct --help status'
  check_equal "${help_output}" "${output}" 'direct --help output'

  output=''
  status=0
  capture output status "${MKTEXT_LIBRARY}" help
  check_status 0 "${status}" 'direct help status'
  check_equal "${help_output}" "${output}" 'direct help output'

  output=''
  status=0
  capture output status "${MKTEXT_LIBRARY}" --version
  check_status 0 "${status}" 'direct --version status'
  check_equal "${version_output}" "${output}" 'direct --version output'

  output=''
  status=0
  capture output status "${MKTEXT_LIBRARY}" version
  check_status 0 "${status}" 'direct version status'
  check_equal "${version_output}" "${output}" 'direct version output'

  if "${MKTEXT_LIBRARY}" foobar >/dev/null 2>&1; then
    status=0
  else
    status=$?
  fi
  check_status 2 "${status}" 'direct unknown operation status'

  if "${MKTEXT_LIBRARY}" >/dev/null 2>&1; then
    status=0
  else
    status=$?
  fi
  check_status 2 "${status}" 'direct missing operation status'
fi

# Context variables are consumed indirectly by name through the public API.
# shellcheck disable=SC2034
declare -A context=()

if ! mktext set context title 'Example'; then
  printf 'FAIL: set rejected a valid associative-array context\n' >&2
  failures=$((failures + 1))
fi

output=''
status=0
capture output status mktext get context TITLE
check_status 0 "${status}" 'get existing key'
check_equal 'Example' "${output}" 'get existing key value'

if mktext exists context title; then
  status=0
else
  status=$?
fi
check_status 0 "${status}" 'exists existing key'

if mktext exists context missing; then
  status=0
else
  status=$?
fi
check_status 1 "${status}" 'exists absent key'

rendered=''
status=0
# This single-quoted string is a literal program passed to bash -c; expansion is
# intentionally deferred to that child shell.
# shellcheck disable=SC2016
capture rendered status bash -c \
  'source "$1"; declare -A c=([TITLE]="Example"); printf "%s" "{TITLE}/{ title }" | mktext render c' \
  _ "${MKTEXT_LIBRARY}"
check_status 0 "${status}" 'render recognized macros'
check_equal 'Example/Example' "${rendered}" 'render recognized macros output'

rendered=''
status=0
# The program is deliberately single-quoted for execution by the child shell.
# shellcheck disable=SC2016
capture rendered status bash -c \
  'source "$1"; declare -A c=([A]="{B}" [B]="expanded"); printf "%s" "{A}" | mktext render c' \
  _ "${MKTEXT_LIBRARY}"
check_status 0 "${status}" 'nonrecursive render status'
check_equal '{B}' "${rendered}" 'nonrecursive render output'

rendered=''
status=0
# The dollar expression is deliberately single-quoted test data and must remain
# literal so the renderer can prove it does not reinterpret shell syntax.
# shellcheck disable=SC2016
capture rendered status bash -c \
  'source "$1"; declare -A c=([TITLE]="changed"); printf "%s" '\''${TITLE} {{TITLE}} {bad key} {UNKNOWN}'\'' | mktext render c' \
  _ "${MKTEXT_LIBRARY}"
check_status 0 "${status}" 'literal preservation status'
# shellcheck disable=SC2016
check_equal '${TITLE} {{TITLE}} {bad key} {UNKNOWN}' "${rendered}" \
  'literal preservation output'

if ! mktext unset context title; then
  printf 'FAIL: unset rejected a valid writable context\n' >&2
  failures=$((failures + 1))
fi

if mktext exists context title; then
  status=0
else
  status=$?
fi
check_status 1 "${status}" 'unset removes key'

use_local_context() {
  # This context is intentionally consumed indirectly by its local variable name.
  # shellcheck disable=SC2034
  local -A local_context=()

  mktext set local_context TITLE 'Local' || return
  mktext get local_context TITLE
}

output=''
status=0
capture output status use_local_context
check_status 0 "${status}" 'caller-local context status'
check_equal 'Local' "${output}" 'caller-local context value'

# This array is likewise consumed indirectly by its variable name.
# shellcheck disable=SC2034
declare -Ar readonly_context=([TITLE]='Readonly')
output=''
status=0
capture output status mktext get readonly_context TITLE
check_status 0 "${status}" 'readonly context get status'
check_equal 'Readonly' "${output}" 'readonly context get value'

if mktext set readonly_context TITLE changed >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
check_status 3 "${status}" 'readonly context mutation status'

# The deliberately reserved name is passed by string to validate rejection.
# shellcheck disable=SC2034
declare -A __mktext_collision=()
if mktext get __mktext_collision TITLE >/dev/null 2>&1; then
  status=0
else
  status=$?
fi
check_status 3 "${status}" 'reserved private context prefix'

if (( failures != 0 )); then
  printf 'Bash %s compatibility: %s failure(s)\n' "${BASH_VERSION}" "${failures}" >&2
  exit 1
fi

printf 'Bash %s compatibility checks passed for %s\n' \
  "${BASH_VERSION}" "${MKTEXT_LIBRARY}"
