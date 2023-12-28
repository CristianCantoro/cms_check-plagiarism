#!/usr/bin/env bash
##############################################################################
# Produce a plagiarism report for CMS submissions.
#
# Usage:
#     ./check_plagiarism.sh
#
# Dependencies:
# * docopts v0.6.1+fix (https://github.com/docopt/docopts)
# * sherlock (http://www.cs.usyd.edu.au/~scilect/sherlock/)
# * JPLAG v4.1.0 (https://github.com/jplag/jplag)
#   (download the jar with dependencies)
#
# ---
# # Copyright (c) 2016-2022 Cristian Consonni
# MIT License
# This is free software: you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.
##############################################################################

#################### options
man=false
debug=false
jplag=false
sherlock=false
verbose=false
jexec=false
SHERLOCK_DEFAULT_BIN="$(command -v sherlock)"
JAVA_DEFAULT_EXEC="$(command -v java)"
JPLAG_DEFAULT_JAR="/opt/jplag/jplag.jar"

read -rd '' docstring <<EOF
Usage:
  check_plagiarism.sh [options] [ --jexec JAVA_EXEC ]
                                [ --jplag JPLAG_JAR ]
                                [ --sherlock SHERLOCK_BIN ]
  check_plagiarism.sh ( -h | --help | --man )
  check_plagiarism.sh ( --version )

  Options:
    -d, --debug                   Enable debug mode (implies --verbose)
    -h, --help                    Show this help message and exits.
    --jexec JAVA_EXEC             Path to java executable
                                  [default: $JAVA_DEFAULT_EXEC]
    --jplag JPLAG_JAR             Path to JPLAG's JAR (w/ deps)
                                  [default: /opt/jplag/jplag.jar]
    --sherlock SHERLOCK_BIN       Path to sherlock's binary
                                  [default: $SHERLOCK_DEFAULT_BIN]
    --man                         Show an extended help message.
    -v, --verbose                 Generate verbose output.
    --version                     Print version and copyright information.
----
check_plagiarism.sh 0.3
copyright (c) 2016-2022 Cristian Consonni
MIT License
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF

eval "$(echo "$docstring" | docopts -V - -h - : "$@" )"

# enhanced bash strict mode
# shellcheck disable=SC2128
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

#################### Utils
if $debug; then
  echodebug() {
    echo -en "[$(date '+%F %k:%M:%S')][debug]\\t"
    echo "$@" 1>&2
  }
else
  echodebug() { true; }
fi

if $debug; then
  verbose=true
fi

if $verbose; then
  echoverbose() {
    echo -en "[$(date '+%F %k:%M:%S')][verbose]\\t"
    echo "$@" 1>&2
  }
else
  echoverbose() { true; }
fi

ansi()          { echo -e "\\e[${1}m${*:2}\\e[0m"; }
bold()          { ansi 1 "$@"; }
italic()        { ansi 3 "$@"; }
underline()     { ansi 4 "$@"; }
strikethrough() { ansi 9 "$@"; }
####################

#################### Documentation helpers

function print_help() {
  eval "$(echo "$docstring" | docopts -V - -h - : '-h' | head -n -1)"
}

function print_man() {

  print_help

  echo -e "$(cat <<MANPAGE

$(bold USAGE)

  Usage:
    ./check_plagiarism.sh

This script assumes the following:
  * a folder called 'allsrc' is located in the current directory
  * JPLAG JAR is located at '/opt/jplag/jplag.jar'
  * sherlock's binary is in your PATH

$(bold DEPENDENCIES)

This script has the following dependencies:

  * docopts, v0.6.1+fix
    download at: https://github.com/docopt/docopts

  * sherlock
    download at: http://www.cs.usyd.edu.au/~scilect/sherlock/

  * JPLAG, v4.1.0
    download the jar with dependencies at: https://github.com/jplag/jplag

MANPAGE
)"

}

if $man; then
  print_man
  exit 0
fi

JPLAG_JAR="$JPLAG_DEFAULT_JAR"
if [ -n "$jplag" ]; then
  JPLAG_JAR="$jplag"
fi

JAVA_EXEC="$JAVA_DEFAULT_EXEC"
if [ -n "$jexec" ]; then
  JAVA_EXEC="$jexec"
fi

SHERLOCK_BIN="$SHERLOCK_DEFAULT_BIN"
if [ -n "$sherlock" ]; then
  SHERLOCK_BIN="$sherlock"
fi

echodebug "SHERLOCK_BIN: $SHERLOCK_BIN"
echodebug "JAVA_EXEC: $JAVA_EXEC"
echodebug "JPLAG_JAR: $JPLAG_JAR"

jplag_version=$(basename "$JPLAG_JAR" | \
  sed -r 's/jplag-([0-9]+.[0-9]+.[0-9]+)-jar-with-dependencies.jar/\1/g')

echoverbose "Using JPLAG at: $JPLAG_JAR (JPLAG JAR version: $jplag_version)"
echoverbose "Using sherlock at: $SHERLOCK_BIN"

SOURCEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echodebug "SOURCEDIR: $SOURCEDIR"

SCRIPTDIR="$SOURCEDIR/scripts"
echodebug "SCRIPTDIR: $SCRIPTDIR"

resdir=$(mktemp -d -p "$SOURCEDIR" -t check_plagiarism.results.XXX)
echoverbose "Checking plagiarism, saving results in $resdir/..."

if [ ! -d 'allsrc' ]; then 
  (>&2 echo "Error: This script assumes you have a directory called 'allsrc/'")
  (>&2 echo "in the current dir $SOURCEDIR")
  exit 1
fi

echoverbose -n "  * step 1: checking all pairs with Sherlock..."

( cd "$SOURCEDIR/allsrc/"
  "$SCRIPTDIR/allpairs.rb" | sort -n -r > "$resdir/allpairs.out"
)
cp "$resdir/allpairs.out" "$resdir/plagiarism_report.sherlock.txt"
if $verbose; then
  echo " done -> $resdir/plagiarism_report.sherlock.txt"
fi

echoverbose "  * step 2: checking with Jplag:"
echoverbose -n "    * 2.a: Check all sources (by group) with JPLAG ..."
set +eo pipefail
"$JAVA_EXEC" -jar "$JPLAG_JAR" \
  -l 'cpp' \
  --cluster-skip \
  -n -1 \
  -m 0.8 \
  -r "$resdir/jplag_all_src" \
  "$SOURCEDIR/allsrc" \
    > "$resdir/jplag_all_src.log"
set -eo pipefail
"$SCRIPTDIR"/report_jplag.py \
  "$resdir/jplag_all_src.log" \
  "$resdir/jplag_all_src.zip"
if $verbose; then
  echo "  done"
fi

echoverbose "    * 2.b: Check only selected sources with JPLAG ..."
echoverbose "        - 2.b.1: Clustering sources with JPLAG ..."

mkdir -p "$resdir/jplag_logs"
mkdir -p "$resdir/jplag_clustered_by_group_src"
mkdir -p "$resdir/jplag_clustered_all_src"
find "$SOURCEDIR/allsrc" -mindepth 1 -type d -print0 | sort -V -z | \
  while IFS= read -r -d '' asourcedir; do
    dirname=$(basename "$asourcedir")
    echodebug "dirname: $dirname"

    set +eo pipefail
    "$JAVA_EXEC" -jar "$JPLAG_JAR" \
        -l 'cpp' \
        -n -1 \
        --cluster-alg AGGLOMERATIVE \
        --cluster-metric MIN \
        -m 0.45 \
        -r "$resdir/jplag_logs/jplag_$dirname" \
        "$asourcedir" \
          > "$resdir/jplag_logs/jplag_$dirname.log"
    set -eo pipefail

    mkdir -p "$resdir/jplag_clustered_by_group_src/$dirname"
    # Reading output of a command into an array in Bash
    #   https://stackoverflow.com/a/32931403/2377454
    mapfile -t sources < <( "$SCRIPTDIR"/clustering_jplag.py \
                              "$resdir/jplag_logs/jplag_$dirname.log" \
                              "$SOURCEDIR/allsrc/$dirname")
    for asource in "${sources[@]}"; do
      # echo "asource: $asource"
      cp "$asource" "$resdir/jplag_clustered_by_group_src/$dirname"
      cp "$asource" "$resdir/jplag_clustered_all_src"
    done
done
if $verbose; then
  echo "  done"
fi

echoverbose -n "        - 2.b.2: Check selected sources (by group) " \
               "with Jplag ..."
set +eo pipefail
"$JAVA_EXEC" -jar "$JPLAG_JAR" \
    -l 'cpp' \
    -n -1 \
    -r "$resdir/jplag_clustered_by_group" \
    "$resdir/jplag_clustered_by_group_src" \
      > "$resdir/jplag_clustered_by_group.log"
set -eo pipefail
"$SCRIPTDIR"/report_jplag.py -g \
  "$resdir/jplag_clustered_by_group.log" \
  "$resdir/jplag_clustered_by_group.zip"
if $verbose; then
  echo "  done"
fi

echoverbose -n "        - 2.b.3: Check selected sources with Jplag ..."
set +eo pipefail
"$JAVA_EXEC" -jar "$JPLAG_JAR" \
    -l 'cpp' \
    -n -1 \
    -r "$resdir/jplag_clustered_all" \
    "$resdir/jplag_clustered_all_src" \
      > "$resdir/jplag_clustered_all.log"
set -eo pipefail
"$SCRIPTDIR"/report_jplag.py -s 0.3 \
  "$resdir/jplag_clustered_all.log" \
  "$resdir/jplag_clustered_all.zip"
if $verbose; then
  echo "  done"
fi


echo "Done!"
echo "1. sherlock results in:"
echo "    - ${resdir}/plagiarism_report.sherlock.txt"
echo "2. JPLAG results in:"
echo "    - ${resdir}/jplag_all_src_report.csv"
echo "    - ${resdir}/jplag_all_src_clusters_report.csv"
echo "    - ${resdir}/jplag_clustered_by_group_report.csv"
echo "    - ${resdir}/jplag_clustered_by_group_clusters_report.csv"
echo "    - ${resdir}/jplag_clustered_all_report.csv"
echo "    - ${resdir}/jplag_clustered_all_clusters_report.csv"
exit 0
