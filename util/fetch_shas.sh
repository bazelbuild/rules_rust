#!/usr/bin/env bash

# Enumerates the list of expected downloadable files, loads the SHAs for each file, then
# dumps the result to //rust:known_shas.bzl
#
# Should be run from workspace root.

export LC_ALL=C

TOOLS="$(cat ./util/fetch_shas_TOOLS.txt)"
TARGETS="$(cat ./util/fetch_shas_TARGETS.txt)"
VERSIONS="$(cat ./util/fetch_shas_VERSIONS.txt)"
BETA_ISO_DATES="$(cat ./util/fetch_shas_BETA_ISO_DATES.txt)"
NIGHTLY_ISO_DATES="$(cat ./util/fetch_shas_NIGHTLY_ISO_DATES.txt)"
RUSTFMT_TARGETS="$(cat ./util/fetch_shas_RUSTFMT_TARGETS.txt)"
RUSTFMT_VERSIONS="$(cat ./util/fetch_shas_RUSTFMT_VERSIONS.txt)"

enumerate_rust_src_keys() {
  for VERSION in $VERSIONS
  do
    echo "rustc-$VERSION-src"
  done
}

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

enumerate_rustfmt_keys() {
    for RUSTFMT_TARGET in $RUSTFMT_TARGETS
    do
        for RUSTFMT_VERSION in $RUSTFMT_VERSIONS
        do
            echo "$RUSTFMT_VERSION-$RUSTFMT_TARGET"
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

echo "$(emit_bzl_file_contents $(enumerate_keys) $(enumerate_rust_src_keys) $(enumerate_rustfmt_keys))" > ./rust/known_shas.bzl
