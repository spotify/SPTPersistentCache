#!/usr/bin/env bash

source "./ci/lib/travis_helpers.sh"

set -euo pipefail

# License conformance
travis_fold_open "License conformance" "Validating source files for license compliance…"
./ci/validate_license_conformance.sh {*/*.{c,h,m},*/**/*.{h,m}}
travis_fold_close "License conformance"

# Executing build actions
echo "Executing build actions: $BUILD_ACTIONS"
xcrun xcodebuild $BUILD_ACTIONS \
   NSUnbufferedIO=YES \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -sdk "$TEST_SDK" \
    -destination "$TEST_DEST" \
    $EXTRA_ARGUMENTS \
        | xcpretty -c -f `xcpretty-travis-formatter`

# Linting
travis_fold_open "Linting" "Linting CocoaPods specification…"
pod spec lint "$PODSPEC" --quick
travis_fold_close "Linting"
