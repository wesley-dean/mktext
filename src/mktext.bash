## @file src/mktext.bash
## @brief Provides deterministic named text substitution for Bash callers.
## @details
## `mktext` is intentionally a small rendering library.  Callers own value
## acquisition and transformation; this file owns only context operations and
## lexical substitution.  Template text and replacement values are always
## treated as data.  They are never evaluated, sourced, or shell-expanded.
##
## The public API consists of one function, `mktext()`.  Private helpers and
## metadata variables use the reserved `__mktext_` prefix.  Caller context
## variables using that prefix are rejected so Bash dynamic scoping cannot make
## a private local variable shadow the requested context.
##
## A generated distribution artifact may initialize the private metadata
## variables before this maintained source is copied into it.  The defaults below
## keep `src/mktext.bash` directly sourceable during development without runtime
## Git, clock, or network access.  The generated artifact also provides the
## interpreter directive and executable permission used for direct informational
## invocation.
##
## @par Examples
## @code
## declare -A context=()
## mktext set context TITLE "Fewer Incidents"
## printf '%s\n' 'Hello, {TITLE}.' | mktext render context
## mktext --version
## @endcode

## @var __mktext_version
## @brief Version metadata reported by `mktext version` and `mktext --version`.
__mktext_version="${__mktext_version:-0.0.0-dev}"

## @var __mktext_build_date
## @brief Source-revision timestamp embedded in a generated artifact.
__mktext_build_date="${__mktext_build_date:-unknown}"

## @var __mktext_build_commit
## @brief Abbreviated source commit embedded in a generated artifact.
__mktext_build_commit="${__mktext_build_commit:-unknown}"

## @fn __mktext_print_usage()
## @brief Writes the complete compact public usage surface.
## @details
## This helper writes only usage text and does not choose the destination stream.
## The dispatcher uses standard output for requested help and redirects the same
## text to standard error after API-usage diagnostics.
##
## @retval 0 Usage text was written successfully.
## @retval 1 Standard output rejected the complete usage text.
__mktext_print_usage() {
  printf '%s\n' \
    'Usage:' \
    '  mktext set CONTEXT KEY VALUE' \
    '  mktext get CONTEXT KEY' \
    '  mktext exists CONTEXT KEY' \
    '  mktext unset CONTEXT KEY' \
    '  mktext render CONTEXT [--start-delimiter STRING] [--end-delimiter STRING]' \
    '  mktext help' \
    '  mktext version' \
    '' \
    'Options:' \
    '      --start-delimiter STRING  Set the literal render start delimiter (default: {).' \
    '      --end-delimiter STRING    Set the literal render end delimiter (default: }).' \
    '                                Set both delimiters to empty strings for bare-key mode.' \
    '  -h, --help                    Show this help text.' \
    '      --version                 Show version and build metadata.'
}

## @fn __mktext_print_version()
## @brief Writes stable three-line artifact identity information.
## @details
## Metadata is fixed when the distribution artifact is built.  Maintained source
## uses development defaults.  This function never queries Git, the clock, or any
## other external runtime state.
##
## @retval 0 Version metadata was written successfully.
## @retval 1 Standard output rejected the complete metadata.
__mktext_print_version() {
  printf 'mktext %s\nbuild_date=%s\ncommit=%s\n' \
    "${__mktext_version}" \
    "${__mktext_build_date}" \
    "${__mktext_build_commit}"
}

## @fn __mktext_usage_error()
## @brief Writes an API-usage diagnostic followed by compact usage text.
## @param $1 Human-readable diagnostic body without the `mktext:` prefix.
## @retval 2 Always returns the public invalid-usage status.
__mktext_usage_error() {
  printf 'mktext: %s\n\n' "$1" >&2 || :
  __mktext_print_usage >&2 || :
  return 2
}

## @fn __mktext_context_info()
## @brief Validates a caller-supplied context and reports its Bash attributes.
## @details
## Bash namerefs are dynamically scoped.  The helper validates the variable
## name and associative-array type before a nameref is created anywhere else.
## Names beginning with `__mktext_` are reserved for library internals and are
## rejected to prevent a private local variable from shadowing caller state.
##
## @param $1 Name of the caller-owned associative-array context.
## @param $2 Name of an internal variable that receives declaration flags.
## @retval 0 The context exists, is an associative array, and is safe to name.
## @retval 1 The name is invalid, reserved, missing, or not associative.
##
## @par Examples
## @code
## __mktext_context_info context __mktext_flags
## @endcode
__mktext_context_info() {
  local __mktext_context_name
  local __mktext_output_name
  local __mktext_declaration
  local __mktext_flags

  __mktext_context_name="$1"
  __mktext_output_name="$2"

  if [[ ! ${__mktext_context_name} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    return 1
  fi

  if [[ ${__mktext_context_name} == __mktext_* ]]; then
    return 1
  fi

  if ! __mktext_declaration="$(declare -p "${__mktext_context_name}" 2>/dev/null)"; then
    return 1
  fi

  if [[ ! ${__mktext_declaration} =~ ^declare[[:space:]]+-([^[:space:]]*)[[:space:]] ]]; then
    return 1
  fi

  __mktext_flags="${BASH_REMATCH[1]}"
  if [[ ${__mktext_flags} != *A* ]]; then
    return 1
  fi

  printf -v "${__mktext_output_name}" '%s' "${__mktext_flags}"
}

## @fn __mktext_normalize_key()
## @brief Validates a public context key and produces its canonical form.
## @details
## Keys use an intentionally narrow ASCII grammar.  Case is normalized to
## uppercase, while hyphens and underscores remain distinct so normalization
## never collapses two visibly different valid keys.
##
## @param $1 Caller-supplied key.
## @param $2 Name of an internal variable that receives the normalized key.
## @retval 0 The key is valid and the output variable was populated.
## @retval 1 The key does not satisfy the public grammar.
##
## @par Examples
## @code
## __mktext_normalize_key title __mktext_key
## @endcode
__mktext_normalize_key() {
  local __mktext_input_key
  local __mktext_output_name

  __mktext_input_key="$1"
  __mktext_output_name="$2"

  if [[ ! ${__mktext_input_key} =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
    return 1
  fi

  printf -v "${__mktext_output_name}" '%s' "${__mktext_input_key^^}"
}

## @fn __mktext_render_bare_line()
## @brief Renders one physical line using delimiter-free key tokens.
## @details
## Bare mode scans maximal runs of characters that can occur in a public key.
## A run is eligible for replacement only when the complete run satisfies the
## public key grammar and exists exactly, with case preserved, in the context.
## This prevents a key such as `TITLE` from matching inside `SUBTITLE`, `1TITLE`,
## or `_TITLE`, and lets hyphenated keys remain ordinary literal names rather
## than regular-expression syntax.
##
## The scanner emits replacement values directly and never places inserted text
## back into the input stream, preserving nonrecursive rendering.
##
## @param $1 Name of a validated associative-array context.
## @param $2 Physical input line without its newline delimiter.
## @retval 0 The line was written successfully.
## @retval 1 Standard output could not accept the complete rendered line.
##
## @par Examples
## @code
## __mktext_render_bare_line context 'TITLE SUBTITLE'
## @endcode
__mktext_render_bare_line() {
  local -n __mktext_context_ref="$1"
  local __mktext_remaining
  local __mktext_token
  local __mktext_character
  local __mktext_token_regex

  __mktext_remaining="$2"
  __mktext_token_regex='^([A-Za-z0-9_-]+)'

  while [[ -n ${__mktext_remaining} ]]; do
    if [[ ${__mktext_remaining} =~ ${__mktext_token_regex} ]]; then
      __mktext_token="${BASH_REMATCH[1]}"

      if [[ ${__mktext_token} =~ ^[A-Za-z][A-Za-z0-9_-]*$ && ${__mktext_context_ref[${__mktext_token}]+_} ]]; then
        if ! printf '%s' "${__mktext_context_ref[${__mktext_token}]}"; then
          return 1
        fi
      else
        if ! printf '%s' "${__mktext_token}"; then
          return 1
        fi
      fi

      __mktext_remaining="${__mktext_remaining:${#__mktext_token}}"
      continue
    fi

    __mktext_character="${__mktext_remaining:0:1}"
    if ! printf '%s' "${__mktext_character}"; then
      return 1
    fi
    __mktext_remaining="${__mktext_remaining:1}"
  done
}

## @fn __mktext_render_delimited_line()
## @brief Renders one physical line using literal start and end delimiters.
## @details
## Delimiters are matched as literal strings with Bash parameter expansion; they
## are never interpreted as regular expressions or shell syntax.  Text between
## a matched delimiter pair must contain only optional ASCII blanks around one
## key.  Present keys are looked up using the established uppercase normalization
## used by delimited macros.
##
## When the default `{` and `}` delimiters are selected, the historical guards
## for `${NAME}` and `{{NAME}}` remain in force so the default grammar remains
## backward compatible.  For any malformed candidate the scanner emits one
## literal input character and resumes scanning, allowing a later valid macro on
## the same line to be recognized without discarding text.
##
## @param $1 Name of a validated associative-array context.
## @param $2 Physical input line without its newline delimiter.
## @param $3 Literal non-empty start delimiter.
## @param $4 Literal non-empty end delimiter.
## @retval 0 The line was written successfully.
## @retval 1 Standard output could not accept the complete rendered line.
##
## @par Examples
## @code
## __mktext_render_delimited_line context 'Hello, {{NAME}}.' '{{' '}}'
## @endcode
__mktext_render_delimited_line() {
  local -n __mktext_context_ref="$1"
  local __mktext_remaining
  local __mktext_start_delimiter
  local __mktext_end_delimiter
  local __mktext_previous
  local __mktext_prefix
  local __mktext_after_start
  local __mktext_inner
  local __mktext_match
  local __mktext_raw_key
  local __mktext_normalized
  local __mktext_next
  local __mktext_character
  local __mktext_key_regex

  __mktext_remaining="$2"
  __mktext_start_delimiter="$3"
  __mktext_end_delimiter="$4"
  __mktext_previous=''
  __mktext_key_regex='^[[:blank:]]*([A-Za-z][A-Za-z0-9_-]*)[[:blank:]]*$'

  while [[ -n ${__mktext_remaining} ]]; do
    __mktext_prefix="${__mktext_remaining%%"${__mktext_start_delimiter}"*}"

    if [[ -n ${__mktext_prefix} ]]; then
      if ! printf '%s' "${__mktext_prefix}"; then
        return 1
      fi

      __mktext_previous="${__mktext_prefix:${#__mktext_prefix}-1:1}"
      __mktext_remaining="${__mktext_remaining:${#__mktext_prefix}}"
      continue
    fi

    __mktext_after_start="${__mktext_remaining:${#__mktext_start_delimiter}}"
    if [[ ${__mktext_after_start} == *"${__mktext_end_delimiter}"* ]]; then
      __mktext_inner="${__mktext_after_start%%"${__mktext_end_delimiter}"*}"
      __mktext_match="${__mktext_start_delimiter}${__mktext_inner}${__mktext_end_delimiter}"
      __mktext_next="${__mktext_remaining:${#__mktext_match}:1}"

      if [[ ${__mktext_inner} =~ ${__mktext_key_regex} ]]; then
        __mktext_raw_key="${BASH_REMATCH[1]}"

        if [[ ${__mktext_start_delimiter} != '{' || ${__mktext_end_delimiter} != '}' || ( ${__mktext_previous} != '{' && ${__mktext_previous} != '$' && ${__mktext_next} != '}' ) ]]; then
          __mktext_normalized="${__mktext_raw_key^^}"

          if [[ ${__mktext_context_ref[${__mktext_normalized}]+_} ]]; then
            if ! printf '%s' "${__mktext_context_ref[${__mktext_normalized}]}"; then
              return 1
            fi
          else
            if ! printf '%s' "${__mktext_match}"; then
              return 1
            fi
          fi

          __mktext_previous="${__mktext_end_delimiter:${#__mktext_end_delimiter}-1:1}"
          __mktext_remaining="${__mktext_remaining:${#__mktext_match}}"
          continue
        fi
      fi
    fi

    __mktext_character="${__mktext_remaining:0:1}"
    if ! printf '%s' "${__mktext_character}"; then
      return 1
    fi

    __mktext_previous="${__mktext_character}"
    __mktext_remaining="${__mktext_remaining:1}"
  done
}

## @fn __mktext_render_line()
## @brief Renders one physical input line with the selected delimiter mode.
## @details
## Two empty delimiters select bare-key tokenization.  Two non-empty delimiters
## select literal-delimiter rendering.  Validation performed by the public
## dispatcher guarantees that this helper never receives a one-sided empty pair.
##
## @param $1 Name of a validated associative-array context.
## @param $2 Physical input line without its newline delimiter.
## @param $3 Selected start delimiter.
## @param $4 Selected end delimiter.
## @retval 0 The line was written successfully.
## @retval 1 Standard output could not accept the complete rendered line.
##
## @par Examples
## @code
## __mktext_render_line context 'Hello, {NAME}.' '{' '}'
## __mktext_render_line context 'Hello, NAME.' '' ''
## @endcode
__mktext_render_line() {
  if [[ -z $3 && -z $4 ]]; then
    __mktext_render_bare_line "$1" "$2"
    return $?
  fi

  __mktext_render_delimited_line "$1" "$2" "$3" "$4"
}

## @fn __mktext_render()
## @brief Streams template data from standard input through the line renderer.
## @details
## `read -r` removes a newline delimiter from a successfully read physical line.
## The helper writes that delimiter back only when `read` reported success,
## preserving the distinction between newline-terminated input and a final
## unterminated line.
##
## Bash uses `read` status 1 for ordinary EOF and for some input failures.  The
## implementation must therefore treat status 1 as end-of-stream and cannot
## distinguish every such failure without adding platform-specific or external
## probing.  Nonzero statuses other than 1 are treated as distinguishable input
## failures.  Output failures reported by `printf` are also mapped to status 4.
##
## @param $1 Name of a validated associative-array context.
## @param $2 Selected start delimiter.
## @param $3 Selected end delimiter.
## @retval 0 The stream reached the Bash status used for EOF after rendering any
## buffered final line.
## @retval 4 A distinguishable input failure or recoverable output failure
## prevented complete rendering.
##
## @par Examples
## @code
## printf '%s\n' '{TITLE}' | __mktext_render context '{' '}'
## @endcode
__mktext_render() {
  local __mktext_context_name
  local __mktext_line
  local __mktext_read_status
  local __mktext_start_delimiter
  local __mktext_end_delimiter

  __mktext_context_name="$1"
  __mktext_start_delimiter="$2"
  __mktext_end_delimiter="$3"

  while :; do
    __mktext_line=''
    if IFS= read -r __mktext_line; then
      __mktext_read_status=0
    else
      __mktext_read_status=$?
    fi

    if (( __mktext_read_status == 0 )); then
      if ! __mktext_render_line "${__mktext_context_name}" "${__mktext_line}" "${__mktext_start_delimiter}" "${__mktext_end_delimiter}"; then
        return 4
      fi

      if ! printf '\n'; then
        return 4
      fi

      continue
    fi

    if [[ -n ${__mktext_line} ]]; then
      if ! __mktext_render_line "${__mktext_context_name}" "${__mktext_line}" "${__mktext_start_delimiter}" "${__mktext_end_delimiter}"; then
        return 4
      fi
    fi

    if (( __mktext_read_status == 1 )); then
      return 0
    fi

    return 4
  done
}

## @fn mktext()
## @brief Dispatches the complete public mktext API.
## @details
## The dispatcher handles context/rendering operations plus the context-free help
## and version forms.  Context operations validate arity, context identity and
## type, key grammar, and mutation safety before touching caller state.  Read-only
## associative arrays are valid for `get`, `exists`, and `render`; `set` and
## `unset` reject them before Bash can raise a fatal read-only assignment error.
##
## Requested public data and informational output use standard output.
## Diagnostics and corrective usage text for API misuse use standard error.
## Ordinary error paths use `return`, never `exit`, so sourcing this library does
## not transfer ownership of the caller's process lifetime.
##
## @param $1 Operation or informational form.
## @param $2 Caller-owned associative-array context name when required.
## @param $3 Key for set/get/exists/unset operations or render option name.
## @param $4 Value for set operations or render option value.
## @retval 0 Operation or requested information succeeded, or `exists` found the
## requested key.
## @retval 1 `get` or `exists` did not find the requested key.
## @retval 2 Operation name, arity, or other API usage is invalid.
## @retval 3 Context or key validation failed.
## @retval 4 A distinguishable recoverable public-data input/output failure
## occurred.
##
## @par Examples
## @code
## declare -A context=()
## mktext set context TITLE 'Example'
## printf '%s' '{TITLE}' | mktext render context
## printf '%s' 'TITLE' | mktext render context --start-delimiter '' --end-delimiter ''
## mktext --help
## mktext --version
## @endcode
mktext() {
  local __mktext_operation
  local __mktext_context_name
  local __mktext_context_flags
  local __mktext_key
  local __mktext_value
  local __mktext_normalized
  local __mktext_start_delimiter
  local __mktext_end_delimiter
  local __mktext_start_delimiter_seen
  local __mktext_end_delimiter_seen

  if (( $# < 1 )); then
    __mktext_usage_error 'expected an operation'
    return $?
  fi

  __mktext_operation="$1"
  shift

  case "${__mktext_operation}" in
    help | -h | --help)
      if (( $# != 0 )); then
        __mktext_usage_error "${__mktext_operation} does not accept arguments"
        return $?
      fi

      if ! __mktext_print_usage; then
        return 4
      fi
      return 0
      ;;
    version | --version)
      if (( $# != 0 )); then
        __mktext_usage_error "${__mktext_operation} does not accept arguments"
        return $?
      fi

      if ! __mktext_print_version; then
        return 4
      fi
      return 0
      ;;
    set)
      if (( $# != 3 )); then
        __mktext_usage_error 'set expects CONTEXT KEY VALUE'
        return $?
      fi
      ;;
    get | exists | unset)
      if (( $# != 2 )); then
        __mktext_usage_error "${__mktext_operation} expects CONTEXT KEY"
        return $?
      fi
      ;;
    render)
      if (( $# < 1 )); then
        __mktext_usage_error 'render expects CONTEXT [--start-delimiter STRING] [--end-delimiter STRING]'
        return $?
      fi
      ;;
    *)
      __mktext_usage_error "unknown operation: ${__mktext_operation}"
      return $?
      ;;
  esac

  __mktext_context_name="$1"

  __mktext_start_delimiter='{'
  __mktext_end_delimiter='}'
  __mktext_start_delimiter_seen=0
  __mktext_end_delimiter_seen=0

  if [[ ${__mktext_operation} == render ]]; then
    shift

    while (( $# > 0 )); do
      case "$1" in
        --start-delimiter)
          if (( __mktext_start_delimiter_seen != 0 )); then
            __mktext_usage_error 'render accepts --start-delimiter at most once'
            return $?
          fi
          if (( $# < 2 )); then
            __mktext_usage_error 'render option --start-delimiter expects STRING'
            return $?
          fi
          __mktext_start_delimiter="$2"
          __mktext_start_delimiter_seen=1
          shift 2
          ;;
        --end-delimiter)
          if (( __mktext_end_delimiter_seen != 0 )); then
            __mktext_usage_error 'render accepts --end-delimiter at most once'
            return $?
          fi
          if (( $# < 2 )); then
            __mktext_usage_error 'render option --end-delimiter expects STRING'
            return $?
          fi
          __mktext_end_delimiter="$2"
          __mktext_end_delimiter_seen=1
          shift 2
          ;;
        *)
          __mktext_usage_error "unknown render option: $1"
          return $?
          ;;
      esac
    done

    if [[ ( -z ${__mktext_start_delimiter} && -n ${__mktext_end_delimiter} ) || ( -n ${__mktext_start_delimiter} && -z ${__mktext_end_delimiter} ) ]]; then
      __mktext_usage_error 'render delimiters must both be empty or both be non-empty'
      return $?
    fi

    if [[ ${__mktext_start_delimiter} == *$'\n'* || ${__mktext_end_delimiter} == *$'\n'* ]]; then
      __mktext_usage_error 'render delimiters must not contain newline characters'
      return $?
    fi
  fi

  if ! __mktext_context_info "${__mktext_context_name}" __mktext_context_flags; then
    printf 'mktext: invalid context: %s\n' "${__mktext_context_name}" >&2
    return 3
  fi

  if [[ ${__mktext_operation} == set || ${__mktext_operation} == unset ]]; then
    if [[ ${__mktext_context_flags} == *r* ]]; then
      printf 'mktext: context is read-only: %s\n' "${__mktext_context_name}" >&2
      return 3
    fi
  fi

  if [[ ${__mktext_operation} == render ]]; then
    __mktext_render "${__mktext_context_name}" "${__mktext_start_delimiter}" "${__mktext_end_delimiter}"
    return $?
  fi

  local -n __mktext_context_ref="${__mktext_context_name}"

  __mktext_key="$2"

  if ! __mktext_normalize_key "${__mktext_key}" __mktext_normalized; then
    printf 'mktext: invalid key: %s\n' "${__mktext_key}" >&2
    return 3
  fi

  case "${__mktext_operation}" in
    set)
      __mktext_value="$3"
      __mktext_context_ref["${__mktext_normalized}"]="${__mktext_value}"
      return 0
      ;;
    get)
      if [[ ${__mktext_context_ref[${__mktext_normalized}]+_} ]]; then
        if ! printf '%s' "${__mktext_context_ref[${__mktext_normalized}]}"; then
          return 4
        fi
        return 0
      fi
      return 1
      ;;
    exists)
      if [[ ${__mktext_context_ref[${__mktext_normalized}]+_} ]]; then
        return 0
      fi
      return 1
      ;;
    unset)
      unset "${__mktext_context_name}[${__mktext_normalized}]"
      return 0
      ;;
  esac

  return 2
}

## @brief Dispatches process arguments only for supported mktext executables.
## @details
## A generated `dist/mktext.bash` artifact is both sourceable and executable.
## `BASH_SOURCE[0]` differs from `$0` when sourced, so this guard leaves the
## caller's shell untouched in library mode.  Concatenated embedding can make
## those values equal inside another executable, so process ownership also
## requires the invocation basename to be exactly `mktext` or `mktext.bash`.
## Other basenames leave the library inert at top level.  When both checks pass,
## the public dispatcher handles the process arguments and its return status
## becomes the process exit status.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  case ${0##*/} in
    mktext | mktext.bash)
      if mktext "$@"; then
        exit 0
      else
        exit $?
      fi
      ;;
  esac
fi