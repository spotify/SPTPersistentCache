#!/usr/bin/env bash
# Grant that custom checks are working.
set -eo pipefail

# shellcheck disable=SC1091
source ./build.sh

# Lint the build script
echo "Linting the build.sh script..."
check ./build.sh
