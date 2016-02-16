#!/usr/bin/env bash
# Copyright (c) 2015-2016 Spotify AB.
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

source "./ci/lib/travis_helpers.sh"

set -euo pipefail

# License conformance
travis_fold_open "License conformance" "Validating source files for license compliance…"
./ci/validate_license_conformance.sh {demo/*{h,m},include/SPTDataLoader/*.h,SPTDataLoader/*.{h,m},SPTDataLoaderTests/*.{h,m}}
travis_fold_close "License conformance"

# Executing build actions
echo "Executing build actions: $BUILD_ACTIONS"
retry_attempts=0
until [ $retry_attempts -ge 2 ]
do
    xcrun xcodebuild $BUILD_ACTIONS \
        NSUnbufferedIO=YES \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -sdk "$TEST_SDK" \
        -destination "$TEST_DEST" \
        $EXTRA_ARGUMENTS \
            | xcpretty -c -f `xcpretty-travis-formatter` && break
    retry_attempts=$[$retry_attempts+1]
    sleep $retry_attempts
done

# Linting
travis_fold_open "Linting" "Linting CocoaPods specification…"
pod spec lint "$PODSPEC" --quick
travis_fold_close "Linting"
