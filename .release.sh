#!/usr/bin/env bash

# grel release hook
# https://github.com/unamatasanatarai/gemini-dev-tools/blob/master/ggrel

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/scripts/config.sh"

APP_NAME="${APP_NAME:-SwiftApp}"
TEST_CMD="./scripts/test.sh"
BUILD_CMD="./scripts/build_dmg.sh && git add -- BUILD_NUMBER && git commit --amend --no-edit"
RELEASE_ASSETS=("build/${APP_NAME}-\${version}.dmg")
