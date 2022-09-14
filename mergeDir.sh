#!/bin/bash

# INPUT:
# dir/
#   a/
#     *.jpg
#   b/
#     *.jpg
#   c/
#     *.jpg
#
# OUTPUT:
# dir/
#   img/
#   other/
#   video/

function dbg {
  if [[ $DEBUG -eq 1 ]]; then
    echo -e "DBG:\t" $@ >&2
  fi
}

function info {
  echo -e "INF:\t" $@ >&2
}

if [[ ! -d "${1}" ]]; then
  echo "Usage!"
  exit 1
fi

phoCon="$(dirname $(realpath "${0}"))/phoCon.sh"
olddir=$(pwd)

cd "${1}"
info "Workdir $(pwd)"

dirs=$(find . -mindepth 1 -maxdepth 1 -type d -\! -name img -\! -name other -\! -name video)

for d in ${dirs}; do
  info "Processing dir ${d}"
  mv "${d}/"* ./
  rmdir "${d}"
  # sort and don't generate small
  "${phoCon}" -s -n ./
done

# generate small for all
"${phoCon}" -g ./

cd "${olddir}"


