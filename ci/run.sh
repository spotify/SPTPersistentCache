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

groupify "macOS SPM tests" swift test

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

#
# RUN TESTS (Xcode)
#

test_macos() {
  xcb test \
    -scheme "SPTPersistentCache" \
    -enableCodeCoverage YES \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_TEST/macos"
}

test_ios() {
  LATEST_IOS_RUNTIME=`xcrun simctl list runtimes | egrep "^iOS" | sort | tail -n 1 | awk '{print $NF}'`
  IOS_UDID=`xcrun simctl create sptpc-ios-tester com.apple.CoreSimulator.SimDeviceType.iPhone-13 "$LATEST_IOS_RUNTIME"`

  xcb test \
    -scheme "SPTPersistentCache" \
    -enableCodeCoverage YES \
    -destination "platform=iOS Simulator,id=$IOS_UDID" \
    -derivedDataPath "$DERIVED_DATA_TEST/ios"
}

test_tvos() {
  LATEST_TVOS_RUNTIME=`xcrun simctl list runtimes | egrep "^tvOS" | sort | tail -n 1 | awk '{print $NF}'`
  TVOS_UDID=`xcrun simctl create sptpc-tvos-tester com.apple.CoreSimulator.SimDeviceType.Apple-TV-1080p "$LATEST_TVOS_RUNTIME"`

  xcb test \
    -scheme "SPTPersistentCache" \
    -enableCodeCoverage YES \
    -destination "platform=tvOS Simulator,id=$TVOS_UDID" \
    -derivedDataPath "$DERIVED_DATA_TEST/tvos"
}

groupify "Run tests for macOS" test_macos
groupify "Run tests for iOS" test_ios
groupify "Run tests for tvOS" test_tvos

#
# CODECOV
#

if [[ "$NO_COVERAGE" == "1" ]]; then
  exit 0
fi

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

coverage_prepare() {
  curl -sfL https://codecov.io/bash > build/codecov.sh
  chmod +x build/codecov.sh
}

coverage_report() {
  [[ "$IS_CI" == "1" ]] || CODECOV_EXTRA="-d"
  build/codecov.sh -F "$1" -D "$DERIVED_DATA_TEST/$1" -X xcodellvm $CODECOV_EXTRA
  if [[ "$IS_CI" == "1" ]]; then
    # clean up coverage files so they don't leak into the next processing run
    rm -f *.coverage.txt
  elif compgen -G "*.coverage.txt" > /dev/null; then
    # move when running locally so they don't get overwritten
    mkdir -p "build/coverage/$1"
    mv *.coverage.txt "build/coverage/$1"
  fi
}

groupify "Coverage preparation" coverage_prepare
groupify "Coverage for macOS" coverage_report macos
groupify "Coverage for tvOS" coverage_report tvos
groupify "Coverage for iOS" coverage_report ios
