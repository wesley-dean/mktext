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

write_fake_minifier() {
  local path=$1

  cat >"${path}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

while (($#)); do
  case $1 in
    -F | --force)
      shift
      ;;
    *)
      printf 'unexpected fake minifier argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

cat
EOF
  chmod 0755 "${path}"
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
    cp "${BASHDEPS_TEST_DOXYGEN_SOURCE}" vendor/doxygen-bash.awk
    cp "${BASHDEPS_TEST_MINIFIER_SOURCE}" vendor/bash-minifier.bash
    chmod 0644 vendor/doxygen-bash.awk vendor/bash-minifier.bash
    ;;
  verify)
    [[ -f vendor/doxygen-bash.awk ]]
    [[ -f vendor/bash-minifier.bash ]]
    cmp "${BASHDEPS_TEST_DOXYGEN_SOURCE}" vendor/doxygen-bash.awk
    cmp "${BASHDEPS_TEST_MINIFIER_SOURCE}" vendor/bash-minifier.bash
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

prepare_fake_dependency_sources() {
  FAKE_BOOTSTRAP="${FIXTURE_ROOT}/released-bashdeps.bash"
  FAKE_DOXYGEN="${FIXTURE_ROOT}/expected-doxygen-bash.awk"
  FAKE_MINIFIER="${FIXTURE_ROOT}/expected-bash-minifier.bash"

  write_fake_bashdeps "${FAKE_BOOTSTRAP}"
  printf '%s\n' '# expected documentation filter bytes' >"${FAKE_DOXYGEN}"
  write_fake_minifier "${FAKE_MINIFIER}"
  FAKE_BOOTSTRAP_DIGEST="$(sha256_of "${FAKE_BOOTSTRAP}")"
}

@test "build fails without the prepared minifier and does not acquire dependencies" {
  rm -rf "${FIXTURE_ROOT}/vendor"

  run env \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    make -C "${FIXTURE_ROOT}" build VERSION=0.0.0-test

  [ "${status}" -ne 0 ]
  [[ "${output}" == *'Missing build dependency vendor/bash-minifier.bash; run make deps or make all'* ]]
  [ ! -e "${FIXTURE_ROOT}/vendor" ]
  [ ! -e "${CURL_SENTINEL}" ]
  [ ! -e "${FIXTURE_ROOT}/dist/mktext.dev.bash" ]
  [ ! -e "${FIXTURE_ROOT}/dist/mktext.bash" ]
  [ ! -e "${FIXTURE_ROOT}/dist/mktext.min.bash" ]
}

@test "build consumes a prepared minifier without using the manifest or network" {
  mkdir -p "${FIXTURE_ROOT}/vendor"
  write_fake_minifier "${FIXTURE_ROOT}/vendor/bash-minifier.bash"
  rm -f "${FIXTURE_ROOT}/dependencies.txt"

  run env \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    make -C "${FIXTURE_ROOT}" build \
      VERSION=0.0.0-test \
      BUILD_DATE=2026-08-18T00:00:00+00:00 \
      BUILD_COMMIT=deadbeefcafe

  [ "${status}" -eq 0 ]
  [ ! -e "${CURL_SENTINEL}" ]

  for artifact in mktext.dev.bash mktext.bash mktext.min.bash; do
    [ -x "${FIXTURE_ROOT}/dist/${artifact}" ]
    [ -f "${FIXTURE_ROOT}/dist/${artifact}.sha256" ]
  done
}

@test "all synchronizes dependencies before building all six artifacts" {
  prepare_fake_dependency_sources
  write_fake_curl

  run env \
    PATH="${FAKE_BIN}:${PATH}" \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    BASHDEPS_TEST_BOOTSTRAP="${FAKE_BOOTSTRAP}" \
    BASHDEPS_TEST_DOXYGEN_SOURCE="${FAKE_DOXYGEN}" \
    BASHDEPS_TEST_MINIFIER_SOURCE="${FAKE_MINIFIER}" \
    make -C "${FIXTURE_ROOT}" all \
      VERSION=0.0.0-test \
      BASHDEPS_URL=https://example.test/bashdeps.bash \
      BASHDEPS_SHA256="${FAKE_BOOTSTRAP_DIGEST}"

  [ "${status}" -eq 0 ]
  [ -x "${FIXTURE_ROOT}/vendor/bashdeps.bash" ]
  cmp "${FAKE_DOXYGEN}" "${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  cmp "${FAKE_MINIFIER}" "${FIXTURE_ROOT}/vendor/bash-minifier.bash"

  for artifact in mktext.dev.bash mktext.bash mktext.min.bash; do
    [ -x "${FIXTURE_ROOT}/dist/${artifact}" ]
    [ -f "${FIXTURE_ROOT}/dist/${artifact}.sha256" ]
  done
}

@test "deps reuses a correct bootstrap and converges stale managed bytes" {
  prepare_fake_dependency_sources
  mkdir -p "${FIXTURE_ROOT}/vendor"
  cp "${FAKE_BOOTSTRAP}" "${FIXTURE_ROOT}/vendor/bashdeps.bash"
  printf '%s\n' 'stale filter bytes' >"${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  printf '%s\n' 'stale minifier bytes' >"${FIXTURE_ROOT}/vendor/bash-minifier.bash"
  write_fake_curl

  run env \
    PATH="${FAKE_BIN}:${PATH}" \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    BASHDEPS_TEST_BOOTSTRAP="${FAKE_BOOTSTRAP}" \
    BASHDEPS_TEST_DOXYGEN_SOURCE="${FAKE_DOXYGEN}" \
    BASHDEPS_TEST_MINIFIER_SOURCE="${FAKE_MINIFIER}" \
    make -C "${FIXTURE_ROOT}" deps \
      BASHDEPS_URL=https://example.test/bashdeps.bash \
      BASHDEPS_SHA256="${FAKE_BOOTSTRAP_DIGEST}"

  [ "${status}" -eq 0 ]
  cmp "${FAKE_DOXYGEN}" "${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  cmp "${FAKE_MINIFIER}" "${FIXTURE_ROOT}/vendor/bash-minifier.bash"
  [ ! -e "${CURL_SENTINEL}" ]
}

@test "deps-check rejects a tampered minifier without network repair" {
  prepare_fake_dependency_sources
  mkdir -p "${FIXTURE_ROOT}/vendor"
  cp "${FAKE_BOOTSTRAP}" "${FIXTURE_ROOT}/vendor/bashdeps.bash"
  cp "${FAKE_DOXYGEN}" "${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  printf '%s\n' 'tampered minifier bytes' >"${FIXTURE_ROOT}/vendor/bash-minifier.bash"
  write_fake_curl

  run env \
    PATH="${FAKE_BIN}:${PATH}" \
    BASHDEPS_CURL_SENTINEL="${CURL_SENTINEL}" \
    BASHDEPS_TEST_BOOTSTRAP="${FAKE_BOOTSTRAP}" \
    BASHDEPS_TEST_DOXYGEN_SOURCE="${FAKE_DOXYGEN}" \
    BASHDEPS_TEST_MINIFIER_SOURCE="${FAKE_MINIFIER}" \
    make -C "${FIXTURE_ROOT}" deps-check \
      BASHDEPS_SHA256="${FAKE_BOOTSTRAP_DIGEST}"

  [ "${status}" -ne 0 ]
  [ ! -e "${CURL_SENTINEL}" ]
  grep -Fxq 'tampered minifier bytes' "${FIXTURE_ROOT}/vendor/bash-minifier.bash"
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
    make -C "${FIXTURE_ROOT}" deps \
      BASHDEPS_URL=https://example.test/bashdeps.bash \
      BASHDEPS_SHA256="${expected_digest}"

  [ "${status}" -ne 0 ]
  [ -e "${CURL_SENTINEL}" ]
  after_digest="$(sha256_of "${FIXTURE_ROOT}/vendor/bashdeps.bash")"
  [ "${after_digest}" = "${before_digest}" ]
  [ ! -e "${FIXTURE_ROOT}/vendor/bashdeps.bash.tmp" ]
}

@test "clean removes generated dependency and artifact state" {
  mkdir -p \
    "${FIXTURE_ROOT}/vendor" \
    "${FIXTURE_ROOT}/dist" \
    "${FIXTURE_ROOT}/doc/reference"
  : >"${FIXTURE_ROOT}/vendor/bashdeps.bash"
  : >"${FIXTURE_ROOT}/vendor/bash-minifier.bash"
  : >"${FIXTURE_ROOT}/vendor/doxygen-bash.awk"
  : >"${FIXTURE_ROOT}/dist/mktext.dev.bash"
  : >"${FIXTURE_ROOT}/dist/mktext.bash"
  : >"${FIXTURE_ROOT}/dist/mktext.min.bash"
  : >"${FIXTURE_ROOT}/doc/reference/index.html"

  run make -C "${FIXTURE_ROOT}" clean

  [ "${status}" -eq 0 ]
  [ ! -e "${FIXTURE_ROOT}/vendor" ]
  [ ! -e "${FIXTURE_ROOT}/dist" ]
  [ ! -e "${FIXTURE_ROOT}/doc/reference" ]
}

@test "all generated consumer flavors remain functional without dependency state" {
  mkdir -p "${FIXTURE_ROOT}/vendor"
  write_fake_minifier "${FIXTURE_ROOT}/vendor/bash-minifier.bash"

  run make -C "${FIXTURE_ROOT}" build \
    VERSION=0.0.0-test \
    BUILD_DATE=2026-08-18T00:00:00+00:00 \
    BUILD_COMMIT=deadbeefcafe
  [ "${status}" -eq 0 ]

  rm -rf "${FIXTURE_ROOT}/vendor"
  rm -f "${FIXTURE_ROOT}/dependencies.txt"

  for artifact in mktext.dev.bash mktext.bash mktext.min.bash; do
    run "${FIXTURE_ROOT}/dist/${artifact}" --version
    [ "${status}" -eq 0 ]
    [ "${lines[0]}" = 'mktext 0.0.0-test' ]
    [ "${lines[1]}" = 'build_date=2026-08-18T00:00:00+00:00' ]
    [ "${lines[2]}" = 'commit=deadbeefcafe' ]
  done
}
