#!/usr/bin/env bats

setup() {
  # shellcheck source=../mktext.bash
  source "${BATS_TEST_DIRNAME}/../mktext.bash"
  declare -gA context=()
  TEST_TMPDIR="${BATS_TMPDIR:-/tmp}/mktext-${BATS_TEST_NUMBER:-$$}"

  rm -rf "${TEST_TMPDIR}"
  mkdir -p "${TEST_TMPDIR}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "set and get normalize keys to uppercase" {
  mktext set context title 'Example'

  run mktext get context TITLE

  [ "${status}" -eq 0 ]
  [ "${output}" = 'Example' ]
}

@test "get preserves an empty value and distinguishes it from absence" {
  mktext set context EMPTY ''

  run mktext get context empty

  [ "${status}" -eq 0 ]
  [ "${output}" = '' ]
}

@test "get returns one without a diagnostic for an absent key" {
  run mktext get context missing

  [ "${status}" -eq 1 ]
  [ "${output}" = '' ]
}

@test "exists uses predicate return statuses" {
  mktext set context PRESENT ''

  run mktext exists context present
  [ "${status}" -eq 0 ]
  [ "${output}" = '' ]

  run mktext exists context absent
  [ "${status}" -eq 1 ]
  [ "${output}" = '' ]
}

@test "unset is idempotent" {
  mktext set context TITLE 'Example'

  mktext unset context title
  mktext unset context title

  run mktext exists context title
  [ "${status}" -eq 1 ]
}

@test "hyphens and underscores remain distinct" {
  mktext set context foo-bar 'hyphen'
  mktext set context foo_bar 'underscore'

  run mktext get context FOO-BAR
  [ "${output}" = 'hyphen' ]

  run mktext get context FOO_BAR
  [ "${output}" = 'underscore' ]
}

@test "invalid keys return status three" {
  run mktext set context 'bad key' value

  [ "${status}" -eq 3 ]
  [[ "${output}" == *'invalid key'* ]]
}

@test "missing and non-associative contexts return status three" {
  run mktext get missing TITLE
  [ "${status}" -eq 3 ]

  ordinary='value'
  run mktext get ordinary TITLE
  [ "${status}" -eq 3 ]
}

@test "reserved private context names are rejected" {
  declare -gA __mktext_collision=()

  run mktext get __mktext_collision TITLE

  [ "${status}" -eq 3 ]
}

@test "read-only contexts support reads and reject mutations" {
  declare -gAr readonly_context=([TITLE]='Example')

  run mktext get readonly_context TITLE
  [ "${status}" -eq 0 ]
  [ "${output}" = 'Example' ]

  run mktext set readonly_context TITLE changed
  [ "${status}" -eq 3 ]
  [[ "${output}" == *'read-only'* ]]
}

@test "render replaces recognized macros case-insensitively" {
  mktext set context TITLE 'Example'

  run bash -c 'source "$1"; declare -A c=([TITLE]="Example"); printf "%s" "{TITLE}/{ title }/{TiTlE}" | mktext render c' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = 'Example/Example/Example' ]
}

@test "render inserts shell-looking values literally" {
  run bash -c 'source "$1"; declare -A c=(); mktext set c VALUE '\''$HOME $(printf pwned) `id` {OTHER}'\''; printf "%s" "{VALUE}" | mktext render c' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = '$HOME $(printf pwned) `id` {OTHER}' ]
}

@test "render is nonrecursive" {
  run bash -c 'source "$1"; declare -A c=([A]="{B}" [B]="expanded"); printf "%s" "{A}" | mktext render c' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = '{B}' ]
}

@test "unknown macros are preserved exactly" {
  run bash -c 'source "$1"; declare -A c=(); printf "%s" "x[{ Missing }]y" | mktext render c' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = 'x[{ Missing }]y' ]
}

@test "malformed and foreign brace syntaxes are preserved" {
  run bash -c 'source "$1"; declare -A c=([TITLE]="changed"); printf "%s" '\''${TITLE} {{TITLE}} {bad key} {foo.bar} {1TITLE}'\'' | mktext render c' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = '${TITLE} {{TITLE}} {bad key} {foo.bar} {1TITLE}' ]
}

@test "macros do not span physical lines" {
  run bash -c 'source "$1"; declare -A c=([TITLE]="changed"); printf "{TIT\\nLE}" | mktext render c' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = $'{TIT\nLE}' ]
}

@test "unknown operation and wrong arity return status two" {
  run mktext nope context
  [ "${status}" -eq 2 ]

  run mktext render context extra
  [ "${status}" -eq 2 ]
}

@test "library remains usable with errexit and nounset enabled" {
  run bash -c 'set -eu; source "$1"; declare -A c=(); mktext set c TITLE Example; printf "%s" "{TITLE}" | mktext render c' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = 'Example' ]
}

@test "render preserves an unterminated final line" {
  mktext set context TITLE 'Example'
  printf '%s' '{TITLE}' >"${TEST_TMPDIR}/input"
  printf '%s' 'Example' >"${TEST_TMPDIR}/expected"

  mktext render context <"${TEST_TMPDIR}/input" >"${TEST_TMPDIR}/actual"
  run cmp "${TEST_TMPDIR}/expected" "${TEST_TMPDIR}/actual"

  [ "${status}" -eq 0 ]
}

@test "render preserves a terminated final line" {
  mktext set context TITLE 'Example'
  printf '%s\n' '{TITLE}' >"${TEST_TMPDIR}/input"
  printf '%s\n' 'Example' >"${TEST_TMPDIR}/expected"

  mktext render context <"${TEST_TMPDIR}/input" >"${TEST_TMPDIR}/actual"
  run cmp "${TEST_TMPDIR}/expected" "${TEST_TMPDIR}/actual"

  [ "${status}" -eq 0 ]
}

@test "render preserves blank lines and empty input" {
  mktext set context TITLE 'Example'
  printf 'a\n\n{TITLE}\n' >"${TEST_TMPDIR}/input"
  printf 'a\n\nExample\n' >"${TEST_TMPDIR}/expected"

  mktext render context <"${TEST_TMPDIR}/input" >"${TEST_TMPDIR}/actual"
  run cmp "${TEST_TMPDIR}/expected" "${TEST_TMPDIR}/actual"
  [ "${status}" -eq 0 ]

  : >"${TEST_TMPDIR}/input"
  mktext render context <"${TEST_TMPDIR}/input" >"${TEST_TMPDIR}/actual"
  [ ! -s "${TEST_TMPDIR}/actual" ]
}

@test "render preserves CRLF line endings" {
  mktext set context TITLE 'Example'
  printf 'x\r\n{TITLE}\r\n' >"${TEST_TMPDIR}/input"
  printf 'x\r\nExample\r\n' >"${TEST_TMPDIR}/expected"

  mktext render context <"${TEST_TMPDIR}/input" >"${TEST_TMPDIR}/actual"
  run cmp "${TEST_TMPDIR}/expected" "${TEST_TMPDIR}/actual"

  [ "${status}" -eq 0 ]
}

@test "replacement values may contain newlines" {
  mktext set context MULTI $'one\ntwo'
  printf '%s' 'x{MULTI}y' >"${TEST_TMPDIR}/input"
  printf 'xone\ntwoy' >"${TEST_TMPDIR}/expected"

  mktext render context <"${TEST_TMPDIR}/input" >"${TEST_TMPDIR}/actual"
  run cmp "${TEST_TMPDIR}/expected" "${TEST_TMPDIR}/actual"

  [ "${status}" -eq 0 ]
}

@test "get preserves embedded and trailing newlines in a stored value" {
  mktext set context MULTI $'one\ntwo\n'
  printf 'one\ntwo\n' >"${TEST_TMPDIR}/expected"

  mktext get context MULTI >"${TEST_TMPDIR}/actual"
  run cmp "${TEST_TMPDIR}/expected" "${TEST_TMPDIR}/actual"

  [ "${status}" -eq 0 ]
}

@test "caller-local associative arrays are valid contexts" {
  use_local_context() {
    local -A local_context=()
    mktext set local_context TITLE 'Local'
    mktext get local_context TITLE
  }

  run use_local_context

  [ "${status}" -eq 0 ]
  [ "${output}" = 'Local' ]
}

@test "unset rejects a read-only context before Bash performs a fatal write" {
  declare -gAr readonly_unset_context=([TITLE]='Example')

  run mktext unset readonly_unset_context TITLE

  [ "${status}" -eq 3 ]
  [[ "${output}" == *'read-only'* ]]
}

@test "get returns four when Bash reports a recoverable output failure" {
  [ -e /dev/full ] || skip '/dev/full is unavailable on this platform'

  run bash -c 'source "$1"; declare -A c=([TITLE]="Example"); mktext get c TITLE >/dev/full' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 4 ]
}

@test "render returns four when Bash reports a recoverable output failure" {
  [ -e /dev/full ] || skip '/dev/full is unavailable on this platform'

  run bash -c 'source "$1"; declare -A c=([TITLE]="Example"); printf "%s" "{TITLE}" | mktext render c >/dev/full' _ "${BATS_TEST_DIRNAME}/../mktext.bash"

  [ "${status}" -eq 4 ]
}
