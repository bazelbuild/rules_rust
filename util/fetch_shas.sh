#!/usr/bin/env bash

# Enumerates the list of expected downloadable files, loads the SHAs for each file, then
# dumps the result to //rust:known_shas.bzl
#
# Should be run from workspace root.

TOOLS="$(cat ./util/fetch_shas_TOOLS.txt)"
TARGETS="$(cat ./util/fetch_shas_TARGETS.txt)"
VERSIONS="$(cat ./util/fetch_shas_VERSIONS.txt)"
BETA_ISO_DATES="$(cat ./util/fetch_shas_BETA_ISO_DATES.txt)"
NIGHTLY_ISO_DATES="$(cat ./util/fetch_shas_NIGHTLY_ISO_DATES.txt)"

enumerate_keys() {
  for TOOL in $TOOLS
  do
    for TARGET in $TARGETS
    do
      for VERSION in $VERSIONS
      do
        echo "$TOOL-$VERSION-$TARGET"
      done

      for ISO_DATE in $BETA_ISO_DATES
      do
        echo "$ISO_DATE/$TOOL-beta-$TARGET"
      done

      for ISO_DATE in $NIGHTLY_ISO_DATES
      do
        echo "$ISO_DATE/$TOOL-nightly-$TARGET"
      done
    done
  done
}

emit_bzl_file_contents() {
  echo "$@" \
    | parallel --trim lr -d ' ' --will-cite 'printf "%s %s\n", {}, $(curl https://static.rust-lang.org/dist/{}.tar.gz.sha256 | cut -f1 --delimiter=" ")' \
    | sed "s/,//g" \
    > /tmp/reload_shas_shalist.txt

  echo "# This is a generated file -- see //util:fetch_shas.sh"
  echo "FILE_KEY_TO_SHA = {"
  cat /tmp/reload_shas_shalist.txt | sort | awk '{print "    \"" $1 "\": \"" $2 "\","}'
  echo "}"
}

echo "$(emit_bzl_file_contents $(enumerate_keys))" > ./rust/known_shas.bzl
