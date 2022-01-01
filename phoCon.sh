#!/bin/bash

#	TODO:
#	1. Create dir struct
#		a) output dir
#		- YEAR/YYMMDD_$NAME/
#		b) input dir
#		- small / orig or
#		- small without folder and orig as subfolder
#	2. Rename files in orig
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
#			- cd input, mkdir orig
#			- mv input/* into orig
#			- cd orig && do $2
#			- cd input && do $3
#			- do $1a in output and mv input there ?
#		- ./xxx.sh folder name
#			- cd folder, if *.jpg and -d orig
#				- sync small -> orig
#			- else
#				- 

set -e

maxCPU=4
SMALL_DIR="small"

function help {
	echo "Usage: " $0 " [option] directory";
	echo -e "\tTODO"
	echo -e "\t-g\trecreate small from orig/img if does not exists"
	echo -e "\t-r\tsync also raw"
	echo -e "\t-n\tprevent generation of small"
	echo -e "\t-s\tenforce default behaviour(sort + gen small)"
	exit 1
}

#set -x

function syncFromSmall {
	small=$(ls ./${SMALL_DIR}/*.jpg 2>/dev/null) || true
	echo "Syncing orig from small"
	if [[ -d "orig/img" && -n ${small+q} ]]; then
		list=$(ls orig/img/*.jpg)
		for i in ${list}; do
			if [[ ! -f "./${SMALL_DIR}/${i##*\/}" ]]; then
				rm -v $i;
			fi
		done
		echo "orig/img synced to small"
	else
		echo "Missing orig/img directory or small images"
	fi
}

function syncRawFromSmall {
	small=$(ls ./${SMALL_DIR}/*.jpg 2>/dev/null) || true
	echo "Syncing raw from small"
	if [[ -d "orig/raw" && -n ${small+q} ]]; then
		list=$(ls orig/raw/*.nef)
		for i in ${list}; do
			if [[ ! -f "./${SMALL_DIR}/$(basename $i .nef).jpg" ]]; then
				rm -v $i;
			fi
		done
		echo "orig/raw synced to small"
	else
		echo "Missing orig/raw directory or small images"
	fi
}

function renameExiv2 {
	#	better than jhead as it also works for *.nef
	#	jhead -n"%04i_%y%m%d_%H%M%S" $LS_PATTERN
	exiv2 -r "%Y%m%d_%H%M%S_:basename:" mv $1
}

function mkSmall {
	list=$(ls ${1:-./}/*.jpg)
	threads=0
	echo "Rotating and creating smaller copies of images"
	if [[ ! -d "./${SMALL_DIR}" ]]; then
		mkdir "./${SMALL_DIR}"
	fi
	for i in $list; do 
		si="./${SMALL_DIR}/${i##*\/}"
		if [[ "$i" -nt "$si" ]]; then
			#	echo "$threads -> convert \"$i\" -resize 1600x900 \"small/$i\"";
			{(
				jhead -autorot -ft "$i";
				convert "$i" -resize 1600x900 "$si"
				jhead -ft -te "$i" "$si"
			) &};
			let threads++,1		#	1 to avoid errors with set -e
								#	due to weird let behaviour
			if [ $threads -eq $maxCPU ]; then wait -n; let threads--,1; fi
		else
			echo "Not generating for $i - already exists"
		fi;
		done
	wait
}

function handleJPG {
	if [[ ! -d "orig/img" ]]; then
		echo "Creating IMG dir"
		mkdir -p orig/img
	fi
	newName="orig/img/${1%.*}.jpg"
	mv "$1" "$newName"
	renameExiv2 "$newName"
}

function handleNEF {
	if [[ ! -d "orig/raw" ]]; then
		echo "Creating RAW dir"
		mkdir -p orig/raw
	fi
	newName="orig/raw/${1%.*}.nef"
	mv "$1" "$newName"
	renameExiv2 "$newName"
}

function handleMOV {
	if [ -z ${dirVIDEO+x} ]; then
		echo "Creating VIDEO dir"
		mkdir orig/video && dirVIDEO=1
	fi
	mv "$1" "orig/video/${1%.*}.mov"
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

while getopts gnrs opt; do
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
		*)
			;;
	esac
	let CNT++,1
done

shift $CNT

if [ $# -eq 0 ]; then help $@; fi

if [ -d $1 ]; then
	echo "Changing directory to: $1" && cd $1
else
	help $@
fi

if [[ ! -d orig || $FORCE_SORT -eq  1 ]]; then
	#	new folder
	echo "New image folder to process"
	mkdir -p orig
	find . -maxdepth 1 -type f -printf '%f\n' | while read f; do
		ftype=$(xdg-mime query filetype $f) 
		case $ftype in
			video/quicktime)
				handleMOV $f
				;;
			image/jpeg)
				handleJPG $f
				;;
			image/x-nikon-nef)
				handleNEF $f
				;;
			*)
				echo "Unknown type: $ftype for $f"
				;;
		esac
	done
	if [[ -d orig/img && $DONT_GEN_SMALL -eq 0 ]]; then
		echo "Create small images"
		mkSmall orig/img
	fi
else
	#	already sorted, try creating small or syncing
	small=$(ls ./${SMALL_DIR}/*.jpg 2>/dev/null) || true
	if [[ -d "orig/img" && ( -z ${small} || $MKSMALL -eq 1 ) && $DONT_GEN_SMALL -eq 0 ]]; then
		echo "Create small images"
		mkSmall orig/img
	elif [[ -d "orig/img" && -n ${small} ]]; then
		echo "Sync from small"
		#	sync small
		syncFromSmall
		if [[ $SRAW -eq 1 ]]; then
			echo "Syncing RAW"
			syncRawFromSmall
		fi
	fi
fi
