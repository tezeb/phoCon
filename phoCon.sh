#!/bin/bash

#	TODO:
#	1. Create dir struct
#		a) output dir
#		- YEAR/YYMMDD_$NAME/
#		b) input dir
#		- small / jpg or
#		- small without folder and jpg as subfolder
#	2. Rename files in jpg
#		- check if small exists, ask to force and sync?
#		- YYMMDD_HHMMSS_%04n.jpg
#		- if file exists
#		- YYMMDD_HHMMSS_%04n_1.jpg
#	3. Create small
#		- copy exif timestamp and touch ??
#	4. For sync
#		- 
#	5. Usage:
#		- ./xxx.sh inputFolder outputFolder name
#			- cd input, mkdir jpg
#			- mv input/* into jpg
#			- cd jpg && do $2
#			- cd input && do $3
#			- do $1a in output and mv input there ?
#		- ./xxx.sh folder name
#			- cd folder, if *.jpg and -d jpg
#				- sync small -> jpg
#			- else
#				- 

set -e

maxCPU=4
SMALL_DIR="img/small"
DEBUG=0

function help {
	echo "Usage: " ${0} " [option] directory";
	echo -e "\tTODO"
	echo -e "\t-g\trecreate small from img/{jpg,tiff,raw} if does not exists"
	echo -e "\t-r\tsync also raw"
	echo -e "\t-n\tprevent generation of small"
	echo -e "\t-s\tenforce default behaviour(sort + gen small)"
	echo -e "\t-R\toperate on direct subdirectories of target"
	echo -e "\t-p\trename subdirectories acording to YYMM_name"
	echo -e "\t-P\trename subdirectories acording to YYYYMMDD_name"
	echo -e "\t-d\tthis will remove orig when small is missing - destructive"
	exit 1
}

#set -x

function dbg {
  if [[ $DEBUG -eq 1 ]]; then
    echo -e "DBG:\t" $@ >&2
  fi
}

function info {
  echo -e "INF:\t" $@ >&2
}

function err {
  echo -e "ERR:\t" $@ >&2
}

function syncFromSmall {
	small=$(ls ./img/${SMALL_DIR}/*.jpg 2>/dev/null) || true
	info "Syncing jpg from small"
	if [[ -d "img/jpg" && -n ${small+q} ]]; then
		list=$(ls img/jpg/*.jpg)
		for i in ${list}; do
			if [[ ! -f "./img/${SMALL_DIR}/${i##*\/}" ]]; then
				rm -v "${i}";
			fi
		done
		info "img/jpg synced to small"
	else
		info "Missing img/jpg directory or small images"
	fi
}

function syncRawFromSmall {
	small=$(ls ./${SMALL_DIR}/*.jpg 2>/dev/null) || true
	info "Syncing raw from small"
	if [[ -d "img/raw" && -n ${small+q} ]]; then
		list=$(ls img/raw/*.nef)
		for i in ${list}; do
			if [[ ! -f "./${SMALL_DIR}/$(basename "${i}" .nef).jpg" ]]; then
				rm -v "${i}"
			fi
		done
		info "img/raw synced to small"
	else
		info "Missing img/raw directory or small images"
	fi
}

function noExifHdr {
  info "Adding EXIF to ${1}"
  jhead -mkexif "${1}" || true
  exiv2 -t -r "%Y%m%d_%H%M%S_:basename:" mv "${1}" || true
}

function renameExiv2 {
	#	better than jhead as it also works for *.nef
	#	jhead -n"%04i_%y%m%d_%H%M%S" $LS_PATTERN
  #exiv2 -t -r "%Y%m%d_%H%M%S_:basename:" mv "${1}" || noExifHdr "${1}"
  # this should work for all filetypes
  exiftool -"FileName<CreateDate" -d %Y%m%d_%H%M%S_%%f%%-c.%%e "${1}"
}

function jpegConvert {
  jhead -q -autorot -ft "${1}" || err "jhead -q -autorot : $?" && true
  convert "${1}" -resize 1600x900 "${2}" || err "convert ${1}" && true
  jhead -q -ft -te "${1}" "${2}" || err "jhead -q -ft -te : $?" && true
  # might need be speed up like this
  # more testing needed
  #convert "$1" -auto-orient -resize 1600x900 "$2"
  #jhead -ft -te "$1" -dt -norot "$2"
}

function tiffConvert {
  # assume that internal thumbnail is the last image
  convert "${1}" -delete 1--1 -resize 1600x900 "${2}"
  touch -r "${1}" "${2}"
}

function rawConvert {
  convert "${1}" -auto-orient -resize 1600x900 "${2}"
  exiv2 -e a- ex "${1}" | exiv2 -i a- in "${2}"
  # need to clear orientation after copying EXIF above
  jhead -q -ft -norot "${2}"
}

function mkSmallAll {
  mkSmall img/jpg
  mkSmall img/tiff tiff tiffConvert
  mkSmall img/raw cr2 rawConvert
  mkSmall img/raw nef rawConvert
}

function mkSmall {
  ext="${2:-jpg}"
  tdir="${1:-./}"
  if [[ ! -d "${tdir}" ]]; then
    return
  fi
	list=$(find "${tdir}" -maxdepth 1 -type f -name "*.${ext}")
  fun="${3:-jpegConvert}"
	threads=0
	info "Rotating and creating smaller copies of images: ${ext}"
	if [[ ! -d "./${SMALL_DIR}" ]]; then
		mkdir -p "./${SMALL_DIR}"
	fi
	for i in $list; do 
    si="./${SMALL_DIR}/$(basename "${i}" ".${ext}").jpg"
		if [[ "$i" -nt "$si" ]]; then
			#	echo "$threads -> convert \"$i\" -resize 1600x900 \"small/$i\"";
			{(
        $fun "$i" "$si" "${ext}"
			) &};
			let threads++,1		#	1 to avoid errors with set -e
								#	due to weird let behaviour
			if [ $threads -eq $maxCPU ]; then wait -n; let threads--,1; fi
		else
			dbg "Not generating for $i - already exists"
		fi;
		done
	wait
}

function handleJPG {
	if [[ ! -d "img/jpg" ]]; then
		info "Creating IMG dir"
		mkdir -p img/jpg
	fi
  newName=$(getNewName "img/jpg/${1%.*}" "jpg")
	mv --backup=t "./${1}" "${newName}"
	renameExiv2 "${newName}"
}

function handleTIFF {
	if [[ ! -d "img/tiff" ]]; then
		info "Creating IMG dir"
		mkdir -p img/tiff
	fi
  newName=$(getNewName "img/tiff/${1%.*}" "tiff")
	mv --backup=t "${1}" "${newName}"
  renameExiv2 "${newName}"
}


function handleRAW {
	if [[ ! -d "img/raw" ]]; then
		info "Creating RAW dir"
		mkdir -p img/raw
	fi
  newName=$(getNewName "img/raw/${1%.*}" "$2")
	mv --backup=t "${1}" "${newName}"
  renameExiv2 "${newName}"
}

function handleNEF {
  handleRAW "${1}" "nef"
}

function handleCR2 {
  handleRAW "${1}" "cr2"
}

function handleCRW {
  handleRAW "${1}" "crw"
}

function getNewName {
  nname="${1}.${2}"
  c=1
  while [[ -f "${nname}" ]]; do
    info "${nname} already exists"
    nname="${1}_${c}.${2}"
    c=$((c+1))
  done
  echo "${nname}"
}

function handleVideo {
	if [[ ! -d "video" ]]; then
		info "Creating VIDEO dir"
		mkdir -p video
	fi
  newName=$(getNewName "video/${1%.*}" "$2")
	mv --backup=t "${1}" "${newName}"
  renameExiv2 "${newName}"
  # return new name of file
  # echo "${newName}"
}

function handleWMV {
  handleVideo "${1}" "wmv"
}

function handleMOV {
  handleVideo "${1}" "mov"
}

function handleMP4 {
  handleVideo "${1}" "mp4"
}

function handleAVI {
  handleVideo "${1}" "avi"
}

function handleOther {
	if [[ ! -d "other" ]]; then
		info "Creating OTHER dir"
		mkdir -p other
	fi
	mv --backup=t "${1}" "other/"
}

function processDir {
  olddir=$(pwd)
  if [ -d "${1}" ]; then
    info "Changing directory to: ${1}" && cd "${1}"
  else
    err "No such directory ${1}"
    return 1
  fi

  if [[ ! -d img || $FORCE_SORT -eq  1 ]]; then
    #	new folder
    info "New image folder to process: ${1}"
    find . -maxdepth 1 -type f -printf '%f\n' | while read f; do
      ftype=$(xdg-mime query filetype "./${f}") 
      dbg "${f}" "${ftype}"
      case $ftype in
        video/quicktime)
          handleMOV "${f}"
          ;;
        video/x-ms-wmv)
          handleWMV "${f}"
          ;;
        image/jpeg)
          handleJPG "${f}"
          ;;
        image/tiff)
          handleTIFF "${f}"
          ;;
        image/x-nikon-nef)
          handleNEF "${f}"
          ;;
        image/x-canon-cr2)
          handleCR2 "${f}"
          ;;
        image/x-canon-crw)
          handleCRW "${f}"
          ;;
        video/x-msvideo)
          handleAVI "${f}"
          ;;
        video/mp4)
          handleMP4 "${f}"
          ;;
        *)
          info "Unknown type: $ftype for ${f}"
          handleOther "${f}"
          ;;
      esac
    done
    if [[ -d "img" && $DONT_GEN_SMALL -eq 0 ]]; then
      info "Create small images"
      mkSmallAll
    fi
  else
    #	already sorted, try creating small or syncing
    small=$(ls ./${SMALL_DIR}/*.jpg 2>/dev/null) || true
    if [[ -d "img" && ( -z ${small} || $MKSMALL -eq 1 ) && $DONT_GEN_SMALL -eq 0 ]]; then
      info "Create small images"
      mkSmallAll
    elif [[ -d "img/jpg" && -n ${small} && $SYNC_AND_DEL -eq 1 ]]; then
      info "Sync from small"
      #	sync small
      syncFromSmall
      if [[ $SRAW -eq 1 ]]; then
        info "Syncing RAW"
        syncRawFromSmall
      fi
    fi
  fi

  cd "${olddir}"

  if [[ PREFIX_YYMM -eq 1 ]]; then

    yymm=$(find "${1}" -type f -printf '%T+ %p\n' | grep -v other | sort | head -n 1 | sed 's/^..\(..\)-\(..\).*/\1\2/')

    dname=$(dirname "${1}")
    bname=$(basename "${1}")

    mv -n "${1}" "${dname}/${yymm}_${bname}"

  elif [[ PREFIX_YYYYMMDD -eq 1 ]]; then

    yymm=$(find "${1}" -type f -printf '%T+ %p\n' | grep -v other | sort | head -n 1 | sed 's/^\(....\)-\(..\)-\(..\).*/\1\2\3/')

    dname=$(dirname "${1}")
    bname=$(basename "${1}")

    mv -n "${1}" "${dname}/${yymm}_${bname}"

  fi
  
}

LS_PATTERN="*.JPG"
SYNC=0
RENAME=0
RENAME_DATE=0

MKSMALL=0
CNT=0
SRAW=0
DONT_GEN_SMALL=0
FORCE_SORT=0
RECURSIVE=0
PREFIX_YYMM=0
PREFIX_YYYYMMDD=0
SYNC_AND_DEL=0

while getopts grnsRpP opt; do
	case $opt in
		g)
			MKSMALL=1
			;;
		r)
			SRAW=1
			;;
		n)
			DONT_GEN_SMALL=1
			;;
		s)
			FORCE_SORT=1
			;;
    R)
      RECURSIVE=1
      ;;
    p)
      PREFIX_YYMM=1
      ;;
    P)
      PREFIX_YYYYMMDD=1
      ;;
    d)
      SYNC_AND_DEL=1
      ;;
		*)
			;;
	esac
	let CNT++,1
done

shift $CNT

if [ $# -eq 0 ]; then help $@; fi

if [[ $RECURSIVE -eq 1 ]]; then
  dbg "Starting recursive"
  find "${1}" -mindepth 1 -maxdepth 1 -type d | while read f; do
    info "${f}"
    processDir "${f}"
  done
else
  processDir "${1}"
fi
