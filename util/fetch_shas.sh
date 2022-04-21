#!/usr/bin/env bash

# Enumerates the list of expected downloadable files, loads the SHAs for each file, then
# dumps the result to //rust:known_shas.bzl

export LC_ALL=C

# Detect workspace root
if [[ -z "${BUILD_WORKSPACE_DIRECTORY}" ]]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    BUILD_WORKSPACE_DIRECTORY="$( dirname "${SCRIPT_DIR}")"
fi

TOOLS="$(cat "${BUILD_WORKSPACE_DIRECTORY}/util/fetch_shas_TOOLS.txt")"
HOST_TOOLS="$(cat "${BUILD_WORKSPACE_DIRECTORY}/util/fetch_shas_HOST_TOOLS.txt")"
TARGETS="$(cat "${BUILD_WORKSPACE_DIRECTORY}/util/fetch_shas_TARGETS.txt")"
VERSIONS="$(cat "${BUILD_WORKSPACE_DIRECTORY}/util/fetch_shas_VERSIONS.txt")"
BETA_ISO_DATES="$(cat "${BUILD_WORKSPACE_DIRECTORY}/util/fetch_shas_BETA_ISO_DATES.txt")"
NIGHTLY_ISO_DATES="$(cat "${BUILD_WORKSPACE_DIRECTORY}/util/fetch_shas_NIGHTLY_ISO_DATES.txt")"

EXTENSIONS=(
   tar.gz
   tar.xz
)

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

  for HOST_TOOL in $HOST_TOOLS
  do
    for VERSION in $VERSIONS
    do
      echo "$HOST_TOOL-$VERSION"
    done
  done
}

emit_bzl_file_contents() {
  if which parallel > /dev/null; then
    for ext in "${EXTENSIONS[@]}"; do
    echo "$@" \
      | parallel --trim lr -d ' ' --will-cite 'printf "%s %s\n", {}, $(curl --fail https://static.rust-lang.org/dist/{}.'"${ext}"'.sha256 | cut -f1 -d" ")' \
      | sed "s/,//g" \
      | grep -v " $" \
      > "${TMPDIR}"/shas.txt
    done
  else
    mkdir "$TMPDIR"/outs

    echo "--parallel" >> "${TMPDIR}"/curl_config
    echo "--fail" >> "${TMPDIR}"/curl_config
    echo "--silent" >> "${TMPDIR}"/curl_config
    echo "--create-dirs" >> "${TMPDIR}"/curl_config
    for key in "$@"; do
      for ext in "${EXTENSIONS[@]}"; do
        echo "--output ${TMPDIR}/outs/${key}.${ext}" >> "${TMPDIR}"/curl_config
        echo "--url https://static.rust-lang.org/dist/${key}.${ext}.sha256" >> "${TMPDIR}"/curl_config
      done
    done
    curl --config "${TMPDIR}"/curl_config

    pushd "$TMPDIR"/outs >/dev/null
        find . -type f -print | \
        awk '{
            file_key=substr($1, 3);
            getline <$1;
            printf("%s %s\n", file_key, $1);
            if (match(file_key, /\.tar\.gz$/)) {
                printf("%s %s\n", substr(file_key, 1, length(file_key)-7), $1);
            }
        }' \
        > "${TMPDIR}"/shas.txt
    popd >/dev/null
  fi

  echo "\"\"\"A module containing a mapping of Rust tools to checksums"
  echo ""
  echo "This is a generated file -- see //util:fetch_shas"
  echo "\"\"\""
  echo ""
  echo "FILE_KEY_TO_SHA = {"
  cat "${TMPDIR}"/shas.txt | sed '/^[[:space:]]*$/d' | sort | awk '{print "    \"" $1 "\": \"" $2 "\","}'
  echo "}"
}

export TMPDIR="$(mktemp -d -t bazel_reload_shas_shalists)"
echo "$(emit_bzl_file_contents $(enumerate_keys))" > "${BUILD_WORKSPACE_DIRECTORY}/rust/known_shas.bzl"
rm -rf "${TMPDIR}"
