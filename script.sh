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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH="$SCRIPT_DIR/bin:$PATH"

set -euo pipefail

# License conformance
travis_fold_open "License conformance" "Validating source files for license compliance…"
validate_license_conformance.sh "$EXPECTED_LICENSE_HEADER_FILE" "$(eval ls "$LICENSED_SOURCE_FILES_GLOB")"
travis_fold_close "License conformance"


# Executing build actions
echo -e "\nExecuting build actions: $BUILD_ACTIONS"
build_cmd="xcrun xcodebuild NSUnbufferedIO=YES"
build_cmd+=" $BUILD_ACTIONS"
build_cmd+=" -project ";        build_cmd+="$PROJECT"
build_cmd+=" -scheme ";         build_cmd+="$SCHEME"
build_cmd+=" -sdk ";            build_cmd+="$TEST_SDK"
build_cmd+=" -destination ";    build_cmd+="$TEST_DEST"

: "${EXTRA_ARGUMENTS:=}"
if [ -n "$EXTRA_ARGUMENTS" ]; then
    echo "Adding extra arguments: $EXTRA_ARGUMENTS"
    build_cmd+=" $EXTRA_ARGUMENTS"
fi

echo "Build command: $build_cmd"
echo
eval "$build_cmd" | xcpretty -c -f "$(xcpretty-travis-formatter)"


# Linting
travis_fold_open "Linting" "Linting CocoaPods specification…"
pod spec lint "$PODSPEC" --quick
travis_fold_close "Linting"
