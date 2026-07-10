#!/bin/bash

heading() {
  echo ""
  echo -e "\033[0;35m** ${*} **\033[0m"
  echo ""
}

fail() {
  >&2 echo "error: $@"
  exit 1
}

xcb() {
  LOG="$1"
  heading "$LOG"
  shift
  export NSUnbufferedIO=YES
  set -o pipefail && xcodebuild \
    -project SPTPersistentCache.xcodeproj \
    -UseSanitizedBuildSystemEnvironment=YES \
    CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
    "$@" | xcbeautify || fail "$LOG failed"
}

build_target() {
  xcb "Build Target [$1] [$2]" build \
    -scheme "$1" \
    -destination "$2" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_COMMON"
}

DERIVED_DATA_COMMON="build/DerivedData/common"
DERIVED_DATA_TEST="build/DerivedData/test"

if [[ -n "$TRAVIS_BUILD_ID" || -n "$GITHUB_WORKFLOW" ]]; then
  heading "Installing Tools"
  gem install cocoapods
  brew install xcbeautify
  export IS_CI=1
fi

heading "Linting Podspec"
pod spec lint SPTPersistentCache.podspec --quick || \
  fail "Podspec lint failed"

heading "Validating License Conformance"
git ls-files | egrep "\\.(h|m|mm)$" | \
  xargs ci/validate_license_conformance.sh ci/expected_license_header.txt || \
  fail "License Validation Failed"

#
# BUILD LIBRARIES (Xcode)
#

build_target SPTPersistentCache "generic/platform=macOS"
build_target SPTPersistentCache "generic/platform=iOS"
build_target SPTPersistentCache "generic/platform=iOS Simulator"
build_target SPTPersistentCache "generic/platform=tvOS"
build_target SPTPersistentCache "generic/platform=tvOS Simulator"
build_target SPTPersistentCache "generic/platform=watchOS"
build_target SPTPersistentCache "generic/platform=watchOS Simulator"

#
# RUN TESTS (spm)
#

swift test || fail "spm tests failed"

#
# RUN TESTS (Xcode)
#

xcb "Run tests for macOS" test \
  -scheme "SPTPersistentCache" \
  -enableCodeCoverage YES \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_TEST/macos"

LATEST_IOS_RUNTIME=`xcrun simctl list runtimes | egrep "^iOS" | sort | tail -n 1 | awk '{print $NF}'`
IOS_UDID=`xcrun simctl create sptpc-ios-tester com.apple.CoreSimulator.SimDeviceType.iPhone-13 "$LATEST_IOS_RUNTIME"`

xcb "Run tests for iOS" test \
  -scheme "SPTPersistentCache" \
  -enableCodeCoverage YES \
  -destination "platform=iOS Simulator,id=$IOS_UDID" \
  -derivedDataPath "$DERIVED_DATA_TEST/ios"

LATEST_TVOS_RUNTIME=`xcrun simctl list runtimes | egrep "^tvOS" | sort | tail -n 1 | awk '{print $NF}'`
TVOS_UDID=`xcrun simctl create sptpc-tvos-tester com.apple.CoreSimulator.SimDeviceType.Apple-TV-1080p "$LATEST_TVOS_RUNTIME"`

xcb "Run tests for tvOS" test \
  -scheme "SPTPersistentCache" \
  -enableCodeCoverage YES \
  -destination "platform=tvOS Simulator,id=$TVOS_UDID" \
  -derivedDataPath "$DERIVED_DATA_TEST/tvos"

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

curl -sfL https://codecov.io/bash > build/codecov.sh
chmod +x build/codecov.sh
[[ "$IS_CI" == "1" ]] || CODECOV_EXTRA="-d"

coverage_report() {
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

coverage_report macos
coverage_report tvos
coverage_report ios
