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
# * JPLAG v2.11.X (https://github.com/jplag/jplag)
#   (download the jar with dependencies)
#
# ---
# # Copyright (c) 2016-2017 Cristian Consonni
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
JPLAG_DEFAULT_JAR="/opt/jplag/jplag.jar"
SHERLOCK_DEFAULT_BIN="$(which sherlock)"

read -rd '' docstring <<EOF
Usage:
  check_plagiarism.sh [options] [ --jplag JPLAG_JAR ]
    [ --sherlock SHERLOCK_BIN ]
  check_plagiarism.sh ( -h | --help | --man )
  check_plagiarism.sh ( --version )

  Options:
    -d, --debug                   Enable debug mode (implies --verbose)
    -h, --help                    Show this help message and exits.
    --jplag JPLAG_JAR             Path to JPLAG's JAR (w/ deps)
                                  [default: /opt/jplag/jplag.jar]
    --sherlock SHERLOCK_BIN       Path to sherlock's binary
                                  [default: $(which sherlock)]
    --man                         Show an extended help message.
    -v, --verbose                 Generate verbose output.
    --version                     Print version and copyright information.
----
check_plagiarism.sh 0.1.0
copyright (c) 2016-2017 Cristian Consonni
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
    echo -en "[$(date '+%F_%k:%M:%S')][debug]\\t"
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
    echo -en "[$(date '+%F_%k:%M:%S')][verbose]\\t"
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

  * JPLAG, v2.11.X
    download the jar with dependencies at: https://github.com/jplag/jplag

MANPAGE
)"

}

if $man; then
  print_man
  exit 0
fi

JPLAG_JAR="$JPLAG_DEFAULT_JAR"
if [ ! -z "$jplag" ]; then
  JPLAG_JAR="$jplag"
fi

SHERLOCK_BIN="$SHERLOCK_DEFAULT_BIN"
if [ ! -z "$sherlock" ]; then
  SHERLOCK_BIN="$sherlock"
fi

echodebug "JPLAG_JAR: $JPLAG_JAR"
echodebug "SHERLOCK_BIN: $SHERLOCK_BIN"
jplag_vstring=$(java -jar "$JPLAG_JAR" | grep -i "version" || false)
jplag_version=$(echo "$jplag_vstring" | \
                  grep -Eo "\\(Version [^\\(]+\\)" | \
                  tr -d 'Version ()')

echoverbose "Using JPLAG at: $JPLAG_JAR (JPLAG JAR version: $jplag_version)"
echoverbose "Using sherlock at: $SHERLOCK_BIN"

SOURCEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echodebug "SOURCEDIR: $SOURCEDIR"

SCRIPTDIR="$SOURCEDIR/scripts"
echodebug "SCRIPTDIR: $SOURCEDIR"

tempdir=$(mktemp -d -p "$SOURCEDIR" -t check_plagiarism.XXXXXXXXXX)
tempdir_name="$(basename "$tempdir")"
echoverbose "Checking plagiarism, saving results in $tempdir_name..."

if [ ! -d 'allsrc' ]; then 
  (>&2 echo "Error: This script assumes you have a directory called 'allsrc/'")
  (>&2 echo "in the current dir $SOURCEDIR")
  exit 1
fi

echoverbose -n "  * step 1: checking all pairs with Sherlock..."

( cd "$SOURCEDIR/allsrc/"
  "$SCRIPTDIR/allpairs.rb" | sort -n -r > "$tempdir/allpairs.out"
)
cp "$tempdir/allpairs.out" "$SOURCEDIR/plagiarism_report.sherlock.txt"
if $verbose; then
  echo " done -> $tempdir_name/allpairs.out"
fi

echoverbose "  * step 2: checking with Jplag:"
echoverbose -n "    * 2.a: producing sources for Jplag..."

( cd "$SOURCEDIR/"
  "$SCRIPTDIR/tojplag.sh" &> "$tempdir/tojplag.log"
  mv "$SOURCEDIR/tojplag" "$tempdir/"
)
if $verbose; then
  echo "  done -> $tempdir_name/tojplag/"
fi

echoverbose -n "    * 2.b: checking selected sources with Jplag..."
java -jar "$JPLAG_JAR" \
    -m 1000 \
    -l 'c/c++' \
    -r "$tempdir/results" \
    "$tempdir/tojplag" \
    > "$tempdir/jplag.log"
if $verbose; then
  echo "  done -> $tempdir_name/jplag.log"
fi

echoverbose -n "    * 2.c: list groups produced by Jplag..."
grep 'Comparing' "$tempdir/jplag.log" > "$tempdir/jplag.clean.log"
( cd "$SOURCEDIR"
"$SCRIPTDIR/list_groups.sh" "$tempdir/jplag.clean.log" > "$tempdir/jplag.out"
)
sort -t':' -k2 -V  -r "$tempdir/jplag.out" > "$tempdir/jplag.out.sorted"
cp "$tempdir/jplag.out.sorted" > "$SOURCEDIR/plagiarism_report.jplag.txt"
if $verbose; then
  echo "  done -> $tempdir_name/jplag.out"
fi

echo "Done!"
echo "all intermediate results in $tempdir_name"
echo "sherlock results in: plagiarism_report.sherlock.txt"
echo "JPLAG results in: plagiarism_report.jplag.txt"
