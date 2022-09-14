#!/bin/sh

function help {
  echo "Usage direction file"
  exit 1
}

if [ $# -ne 2 ]; then help $@; fi

filename=$(basename -- "${2}")
extension="${filename##*.}"
filename="${filename%.*}"

outdir="$(dirname "${2}")"

echo "Rotating ${2} in the ${outdir}"

prime-run ffmpeg -hwaccel cuda -loglevel error -i "${2}" -vf transpose="${1}" -qscale 0 -c:a copy "${outdir}/x.${extension}"

mv "${outdir}/x.${extension}" "${2}"
