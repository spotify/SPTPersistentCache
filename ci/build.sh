#!/usr/bin/env bash
set -eo pipefail
test -n "${DEBUG:-}" && set -x

success() {
  printf "\r  [ \033[00;32mOK\033[0m ] Linting %s...\n" "$1"
}

fail() {
  printf "\r  [\033[0;31mFAIL\033[0m] Linting %s...\n" "$1"
  exit 1
}

info() {
  printf "\r  [ \033[00;34m??\033[0m ] %s\n" "$1"
}

check() {
  local script="$1"
  shellcheck "$script" || fail "$script"
  success "$script"
}

find_scripts() {
  git ls-tree -r HEAD | egrep '^1007|.*\..*sh$' | awk '{print $4}'
}

is_compatible() {
  head -n1 "$1" | egrep -w "sh|bash|ksh" > /dev/null 2>&1
}

check_all_executables() {
  echo "Linting all executables and .*sh files..."
  find_scripts | while read -r script; do
    if is_compatible "$script"; then
      check "$script"
    else
      info "Skipping $script..."
    fi
  done
}

# if being executed, check all executables, otherwise do nothing
if [ $SHLVL -gt 1 ]; then
  check_all_executables
else
  return 0
fi
