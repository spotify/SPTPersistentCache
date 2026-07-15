#!/bin/bash
set -e

if [[ -n "$TRAVIS_BUILD_ID" || -n "$GITHUB_WORKFLOW" ]]; then
  export IS_CI=1
fi

DERIVED_DATA_COMMON="build/DerivedData/common"
DERIVED_DATA_TEST="build/DerivedData/test"

groupify() {
  echo "::group::$1"
  shift
  (
      trap 'echo "::endgroup::"' EXIT
      "$@" 
  )
}

xcb() {
  set -o pipefail && NSUnbufferedIO=YES xcodebuild \
    -UseSanitizedBuildSystemEnvironment=YES \
    CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
    "$@" | xcbeautify
}

build_target() {
  groupify "Build for $1" xcb build \
    -scheme SPTPersistentCache \
    -destination "$1" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_COMMON"
}

install_tools() {
  gem install cocoapods
  brew install xcbeautify
}

validate_license_conformance() {
  git ls-files | egrep "\\.(h|m|mm)$" | \
    xargs ci/validate_license_conformance.sh ci/expected_license_header.txt
}

if [[ "$IS_CI" == "1" ]]; then
  groupify "Install Tools" install_tools
fi

groupify "Lint Podspec" \
  pod spec lint SPTPersistentCache.podspec --quick

groupify "Validate License Conformance" validate_license_conformance

#
# RUN TESTS (spm + macos)
#

groupify "macOS SPM tests" swift test --enable-code-coverage

coverage_report() {
  # output a bunch of stuff that codecov might recognize
  if [[ -n "$GITHUB_WORKFLOW" ]]; then
    PR_CANDIDATE=`echo "$GITHUB_REF" | egrep -o "pull/\d+" | egrep -o "\d+"`
    [[ -n "$PR_CANDIDATE" ]] && export VCS_PULL_REQUEST="$PR_CANDIDATE"
    export CI_BUILD_ID="$RUNNER_TRACKING_ID"
    export CI_JOB_ID="$RUNNER_TRACKING_ID"
    export CODECOV_SLUG="$GITHUB_REPOSITORY"
    export GIT_BRANCH="$GITHUB_REF"
    export GIT_COMMIT="$GITHUB_SHA"
    export VCS_BRANCH_NAME="$GITHUB_REF"
    export VCS_COMMIT_ID="$GITHUB_SHA"
    export VCS_SLUG="$GITHUB_REPOSITORY"
  fi
  
  mkdir -p build
  curl -sfL https://codecov.io/bash > build/codecov.sh
  chmod +x build/codecov.sh

  [[ "$IS_CI" == "1" ]] || CODECOV_EXTRA="-d"

  # h4x to trick codecov
  for bundle in .build/debug/*.xctest ; do
    parent="$(dirname "$bundle")"
    ln -sf "$PWD/$bundle" "${parent}/codecov"
  done

  build/codecov.sh -X xcodellvm $CODECOV_EXTRA -D ".build/debug/codecov" -F "macspm"
}

if [[ "$NO_COVERAGE" != "1" ]]; then
  groupify "Process Coverage" coverage_report
fi

#
# BUILD LIBRARIES (xcodebuild)
#

build_target "generic/platform=macOS"
build_target "generic/platform=iOS"
build_target "generic/platform=iOS Simulator"
build_target "generic/platform=tvOS"
build_target "generic/platform=tvOS Simulator"
build_target "generic/platform=watchOS"
build_target "generic/platform=watchOS Simulator"
