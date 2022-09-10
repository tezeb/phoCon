#!/bin/bash

# mergeSorted.sh target dir1 dir2 [...]

tdir="${1}"
shift

if [[ ! -d "${tdir}" ]]; then
  echo "Usage"
  exit 1
fi

function moveDirContent {
  if [[ -d "${1}/${3}" ]]; then
    mkdir -p "${2}/${3}"
    mv -n "${1}/${3}/"* "${2}/${3}/"
    rmdir "${1}/${3}"
  fi
}

for i in "$@"; do
  moveDirContent "${i}" "${tdir}" "img/jpg" 
  moveDirContent "${i}" "${tdir}" "img/tiff" 
  moveDirContent "${i}" "${tdir}" "img/raw" 
  moveDirContent "${i}" "${tdir}" "img/small" 
  moveDirContent "${i}" "${tdir}" "video"
  moveDirContent "${i}" "${tdir}" "other"
  rmdir "${i}/img" "${i}"
done
