#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  FIXTURE_ROOT="${BATS_TEST_TMPDIR}/mktext-build-deps-${BATS_TEST_NUMBER}"
  FAKE_BIN="${FIXTURE_ROOT}/bin"
  CURL_SENTINEL="${FIXTURE_ROOT}/curl-called"

  rm -rf "${FIXTURE_ROOT}"
  mkdir -p "${FIXTURE_ROOT}/src" "${FAKE_BIN}"

  cp "${REPO_ROOT}/Makefile" "${FIXTURE_ROOT}/Makefile"
  cp "${REPO_ROOT}/dependencies.txt" "${FIXTURE_ROOT}/dependencies.txt"
  cp "${REPO_ROOT}/src/mktext.bash" "${FIXTURE_ROOT}/src/mktext.bash"
}

teardown() {
  rm -rf "${FIXTURE_ROOT}"
}

sha256_of() {
  local path=$1

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${path}" | awk '{print $1}'
  else
    shasum -a 256 "${path}" | awk '{print $1}'
  fi
}

write_fake_bashdeps() {
  local path=$1

  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

command=${1:-}
manifest=${2:-}

[[ -f ${manifest} ]]

case ${command} in
  sync)
    mkdir -p vendor
    cp "${BASHDEPS_TEST_DEP_SOURCE}" vendor/doxygen-bash.awk
    chmod 0644 vendor/doxygen-bash.awk
    ;;
  verify)
    [[ -f vendor/doxygen-bash.awk ]]
    cmp "${BASHDEPS_TEST_DEP_SOURCE}" vendor/doxygen-bash.awk
    ;;
  *)
    printf '%s\n' "unexpected fake bashdeps command: ${command}" >&2
    exit 2
    ;;
esac
EOF
  chmod 0755 "${path}"
}

write_fake_curl() {
  cat >"${FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=''
while (($#)); do
  case $1 in
    -o)
      output=$2
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[[ -n ${output} ]]
: >"${BASHDEPS_CURL_SENTINEL}"
cp "${BASHDEPS_TEST_BOOTSTRAP}" "${output}"
EOF
  chmod 0755 "${FAKE_BIN}/curl"
}

@test "build and all remain independent of documentation dependencies" {
  run make -C "${FIXTURE_ROOT}" build VERSION=0.0.0-test
  [ "${status}" -eq 0 ]
  [ -x "${FIXTURE_ROOT}/dist/mktext.bash" ]
  [ ! -e "${FIXTURE_ROOT}/vendor" ]

  rm -rf "${FIXTURE_ROOT}/dist"

  run env \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    make -C "${FIXTURE_ROOT}" all VERSION=0.0.0-test

  [ "${status}" -eq 0 ]
  [ -x "${FIXTURE_ROOT}/dist/mktext.bash" ]
  [ ! -e "${FIXTURE_ROOT}/vendor" ]
  [ ! -e "${CURL_SENTINEL}" ]
}

@test "deps bootstraps bashdeps and synchronizes the documentation dependency" {
  local bootstrap dependency bootstrap_digest

  bootstrap="${FIXTURE_ROOT}/released-bashdeps.bash"
  dependency="${FIXTURE_ROOT}/expected-doxygen-bash.awk"
  write_fake_bashdeps "${bootstrap}"
  printf '%s\n' '# expected documentation filter bytes' >"${dependency}"
  bootstrap_digest="$(sha256_of "${bootstrap}")"
  write_fake_curl

  run env \
    PATH="${FAKE_BIN}:${PATH}" \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    BASHDEPS_TEST_BOOTSTRAP="${bootstrap}" \
    BASHDEPS_TEST_DEP_SOURCE="${dependency}" \
    make -C "${FIXTURE_ROOT}" deps \
      BASHDEPS_URL=https://example.test/bashdeps.bash \
      BASHDEPS_SHA256="${bootstrap_digest}"

  [ "${status}" -eq 0 ]
  [ -x "${FIXTURE_ROOT}/vendor/bashdeps.bash" ]
  cmp "${bootstrap}" "${FIXTURE_ROOT}/vendor/bashdeps.bash"
  cmp "${dependency}" "${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  [ -e "${CURL_SENTINEL}" ]
}

@test "deps reuses a correct bootstrap and converges stale managed bytes" {
  local bootstrap dependency bootstrap_digest

  bootstrap="${FIXTURE_ROOT}/released-bashdeps.bash"
  dependency="${FIXTURE_ROOT}/expected-doxygen-bash.awk"
  write_fake_bashdeps "${bootstrap}"
  printf '%s\n' '# expected documentation filter bytes' >"${dependency}"
  bootstrap_digest="$(sha256_of "${bootstrap}")"

  mkdir -p "${FIXTURE_ROOT}/vendor"
  cp "${bootstrap}" "${FIXTURE_ROOT}/vendor/bashdeps.bash"
  printf '%s\n' 'stale filter bytes' >"${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  write_fake_curl

  run env \
    PATH="${FAKE_BIN}:${PATH}" \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    BASHDEPS_TEST_BOOTSTRAP="${bootstrap}" \
    BASHDEPS_TEST_DEP_SOURCE="${dependency}" \
    make -C "${FIXTURE_ROOT}" deps \
      BASHDEPS_URL=https://example.test/bashdeps.bash \
      BASHDEPS_SHA256="${bootstrap_digest}"

  [ "${status}" -eq 0 ]
  cmp "${dependency}" "${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  [ ! -e "${CURL_SENTINEL}" ]
}

@test "deps-check rejects tampered dependency bytes without network repair" {
  local bootstrap dependency bootstrap_digest

  bootstrap="${FIXTURE_ROOT}/released-bashdeps.bash"
  dependency="${FIXTURE_ROOT}/expected-doxygen-bash.awk"
  write_fake_bashdeps "${bootstrap}"
  printf '%s\n' '# expected documentation filter bytes' >"${dependency}"
  bootstrap_digest="$(sha256_of "${bootstrap}")"

  mkdir -p "${FIXTURE_ROOT}/vendor"
  cp "${bootstrap}" "${FIXTURE_ROOT}/vendor/bashdeps.bash"
  printf '%s\n' 'tampered filter bytes' >"${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  write_fake_curl

  run env \
    PATH="${FAKE_BIN}:${PATH}" \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    BASHDEPS_TEST_BOOTSTRAP="${bootstrap}" \
    BASHDEPS_TEST_DEP_SOURCE="${dependency}" \
    make -C "${FIXTURE_ROOT}" deps-check \
      BASHDEPS_SHA256="${bootstrap_digest}"

  [ "${status}" -ne 0 ]
  [ ! -e "${CURL_SENTINEL}" ]
  grep -Fxq 'tampered filter bytes' "${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
}

@test "failed bootstrap verification does not publish candidate bytes" {
  local expected_bootstrap bad_bootstrap expected_digest before_digest after_digest

  expected_bootstrap="${FIXTURE_ROOT}/expected-bashdeps.bash"
  bad_bootstrap="${FIXTURE_ROOT}/bad-bashdeps.bash"
  write_fake_bashdeps "${expected_bootstrap}"
  printf '%s\n' '#!/usr/bin/env bash' 'printf bad-bootstrap\\n' >"${bad_bootstrap}"
  chmod 0755 "${bad_bootstrap}"
  expected_digest="$(sha256_of "${expected_bootstrap}")"

  mkdir -p "${FIXTURE_ROOT}/vendor"
  printf '%s\n' 'preexisting invalid bootstrap bytes' >"${FIXTURE_ROOT}/vendor/bashdeps.bash"
  before_digest="$(sha256_of "${FIXTURE_ROOT}/vendor/bashdeps.bash")"
  write_fake_curl

  run env \
    PATH="${FAKE_BIN}:${PATH}" \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    BASHDEPS_TEST_BOOTSTRAP="${bad_bootstrap}" \
    BASHDEPS_TEST_DEP_SOURCE="${FIXTURE_ROOT}/unused" \
    make -C "${FIXTURE_ROOT}" deps \
      BASHDEPS_URL=https://example.test/bashdeps.bash \
      BASHDEPS_SHA256="${expected_digest}"

  [ "${status}" -ne 0 ]
  [ -e "${CURL_SENTINEL}" ]
  after_digest="$(sha256_of "${FIXTURE_ROOT}/vendor/bashdeps.bash")"
  [ "${after_digest}" = "${before_digest}" ]
  [ ! -e "${FIXTURE_ROOT}/vendor/bashdeps.bash.tmp" ]
}

@test "clean removes generated dependency state" {
  mkdir -p \
    "${FIXTURE_ROOT}/vendor" \
    "${FIXTURE_ROOT}/dist" \
    "${FIXTURE_ROOT}/doc/reference"
  : >"${FIXTURE_ROOT}/vendor/bashdeps.bash"
  : >"${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  : >"${FIXTURE_ROOT}/dist/mktext.bash"
  : >"${FIXTURE_ROOT}/doc/reference/index.html"

  run make -C "${FIXTURE_ROOT}" clean

  [ "${status}" -eq 0 ]
  [ ! -e "${FIXTURE_ROOT}/vendor" ]
  [ ! -e "${FIXTURE_ROOT}/dist" ]
  [ ! -e "${FIXTURE_ROOT}/doc/reference" ]
}

@test "generated consumer artifact remains functional without dependency state" {
  run make -C "${FIXTURE_ROOT}" build \
    VERSION=0.0.0-test \
    BUILD_DATE=2026-08-18T00:00:00+00:00 \
    BUILD_COMMIT=deadbeefcafe
  [ "${status}" -eq 0 ]

  rm -rf "${FIXTURE_ROOT}/vendor"
  rm -f "${FIXTURE_ROOT}/dependencies.txt"

  run "${FIXTURE_ROOT}/dist/mktext.bash" --version

  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = 'mktext 0.0.0-test' ]
  [ "${lines[1]}" = 'build_date=2026-08-18T00:00:00+00:00' ]
  [ "${lines[2]}" = 'commit=deadbeefcafe' ]
}
