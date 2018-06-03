#!/usr/bin/env bash
##############################################################################
# List similarity scores between groups.
#
# Usage:
#     ./list_groups.sh JPLAG_REPORT
#
##############################################################################

# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

function get_group_data() {
    local d3='[[:digit:]]{1,3}'
    local dp='[[:digit:]]+'
    while read -r groupinfo; do
        echo "$groupinfo" | 
            sed -E "s#sub($d3)_($d3)_($d3)\\.($dp)_\\.cpp:?#\\1 \\2 \\3.\\4#"
    done
}


JPLAG_REPORT="$1"
SEARCH_TERM="Comparing"
fline=$(grep -n -m 1 "$SEARCH_TERM" "$JPLAG_REPORT" | \
		sed  's/\([0-9]*\).*/\1/')

tail -n+"$fline" "$JPLAG_REPORT" | grep "$SEARCH_TERM" | \
        while read -r line; do
    # echo "$line"
    sources=$(echo "$line" | awk '{print $2}')
    sim=$(echo "$line" | awk '{print $3}')

    group1=$(echo "$sources" | awk -F'-' '{print $1}' | get_group_data)
    group2=$(echo "$sources" | awk -F'-' '{print $2}' | get_group_data)

    declare -A g1
    declare -A g2

    # shellcheck disable=SC2154
    {
    g1[id_]=$(echo "$group1" | awk '{print $1}')
    g1[sub]=$(echo "$group1" | awk '{print $2}')
    g1[points]=$(echo "$group1" | awk '{print $3}')
    }

    g2[id_]=$(echo "$group2" | awk '{print $1}')
    g2[sub]=$(echo "$group2" | awk '{print $2}')
    g2[points]=$(echo "$group2" | awk '{print $3}')

    # echo "group1: $group1 - group2: $group2"
    if [[ "${g1['id_']}" != "${g2['id_']}" ]]; then
        echo -n "${g1['id_']} (${g1['sub']}@${g1['points']})"
        echo -n " -> "
        echo -n "${g2['id_']} (${g2['sub']}@${g2['points']})"
        echo -n ": "
        echo "$sim"
    fi

done
