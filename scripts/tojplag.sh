#!/usr/bin/env bash

# enhanced bash strict mode
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

rm -rf tojplag/
mkdir tojplag

for i in allsrc/*; do
    cd "$i"
    echo "$i"
    for f in $(../../scripts/clustering.rb); do
      cp "$f" ../../tojplag/
    done

    cd ../..
    echo "---"
done
