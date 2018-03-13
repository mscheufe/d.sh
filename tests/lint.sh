#!/usr/bin/env bash
# run the code through shellcheck
shopt -s globstar
cd .. || exit 1
if shellcheck -e SC2164,SC2139,SC2140,SC1091,SC2034 ./**/[d-t]*.sh; then
    echo "shellcheck linting passed"
    exit 0
fi
exit 1
