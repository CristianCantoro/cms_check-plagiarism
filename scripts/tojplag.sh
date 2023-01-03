#!/usr/bin/env bash

# enhanced bash strict mode
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

rm -rf tojplag/
mkdir tojplag

for i in allsrc/*; do
    cd "$i"
    echo "$i"
    for f in $("$scriptdir"/clustering.rb); do
      cp "$f" ../../tojplag/
    done

    cd ../..
    echo "---"
done
