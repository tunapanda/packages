#!/bin/bash

if ! $(which fpm &>/dev/null) 
then
	echo ""
	echo "ERROR: Missing fpm"
	echo "       You seem to be missing the fpm utility, which is required to build packages"
	echo "       Get it here, then try again: https://www.github.com/jordansissel/fpm/"
	echo ""
	exit 2
fi

function script_dir() {
	# Prints the name of the directory where this script lives.
	# Uses a symlink-aware technique for finding script directory, originally from:
	#   http://stackoverflow.com/questions/59895/
	SOURCE="${BASH_SOURCE[0]}"
	while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
	  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	  SOURCE="$(readlink "$SOURCE")"
	  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
	  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" 	
	done
	cd -P "$( dirname "$SOURCE" )" && pwd
}
BASE_DIR=$(script_dir)

DATESTAMP=$(date +%Y%m%d%H%M)
function defaults() {
	USE_DATESTAMP=true
	VERSION=1.0
	ARCH="all"
	URL="https://github.com/tunapanda"
	OUTPUT_DIR="$BASE_DIR/Packages"
	[ -e $BASE_DIR/build_settings ] && . $BASE_DIR/build_settings 	
}


if [ $# -eq 0 ]
then
	echo USAGE: $(basename $0) PACKAGE_DIR... >&2
	exit 1
fi

BUILT=""
for d in $@
do
	# If a dir doesn't have build_settings, it's not a package dir
	[ -f $d/build_settings ] || continue

	# Set package-specific options
	unset NAME PKGNAME 
	defaults ; . $d/build_settings
	[ -z "$NAME" ] && NAME=$(basename $d)

	# Must have a description in build_settings
	# Everything else has a default to fall back on
	if [ -z "DESCRIPTION" ]
	then
		echo ""
		echo "ERROR: Required setting missing. Set DESCRIPTION in $d/build_settings"
		echo ""
		exit 3
	fi


	DEPS=""
	for dep in $DEPENDENCIES
	do
		DEPS="$DEPS -d $dep"	
	done

	# Nothing to do if there's already a .deb and the 
	# directory hasn't been changed since it was created
	EXISTING=$( find $OUTPUT_DIR  -regex '.*/'${NAME}'_'${VERSION}'\(-[0-9]+\)?_[^/]*.deb$' )
	if [ -n "$EXISTING" ]
	then
		LATEST=$(ls -t $EXISTING | head -n1)
		[ $(find $d/scripts $d/fs -newer $LATEST 2>/dev/null | wc -l) -eq 0 ] && continue

	fi

	# If USE_DATESTAMP is enabled, embed datestamp into version
	# This lets you upgrade without forcing during development
	[ $USE_DATESTAMP ] && VERSION=${VERSION}-${DATESTAMP}
	[ -z "$PKGNAME" ] && PKGNAME="${NAME}_${VERSION}_${ARCH}.deb"
	
	# Everything from here on occurs in the package directory
	pushd $d &> /dev/null

	# Include {pre,post}{install,uninstall} scripts if they exist
	SCRIPTS=""
	if [ -d scripts ] 
	then
		[ -e scripts/pre-install.sh ]	&& SCRIPTS="$SCRIPTS --before-install scripts/pre-install.sh"
		[ -e scripts/post-install.sh ] 	&& SCRIPTS="$SCRIPTS --after-install scripts/post-install.sh"
		[ -e scripts/pre-remove.sh ] 	&& SCRIPTS="$SCRIPTS --before-remove scripts/pre-remove.sh"
		[ -e scripts/post-remove.sh ] 	&& SCRIPTS="$SCRIPTS --after-remove scripts/post-remove.sh"
	fi

	( 
		# TODO: Would love to do this in a less ugly way by storing the command and args in a variable
		# and then using it for the echo and the execution, but I can't figure out how to make bash 
		# quote $DESCRIPTION properly when stored in a var
		echo ==RUNNING: \
			fpm -s dir -t deb -C fs -a $ARCH \
			--url $URL \
			-n $NAME \
			--description "$DESCRIPTION" \
			-v $VERSION \
			$SCRIPTS \
			$DEPS \
			-p $OUTPUT_DIR/$PKGNAME \
			$(cd fs; ls) 
		fpm -s dir -t deb -C fs -a $ARCH \
			--url $URL \
			-n $NAME \
			--description "$DESCRIPTION" \
			-v $VERSION \
			$SCRIPTS \
			$DEPS \
			-p $OUTPUT_DIR/$PKGNAME \
			$(cd fs; ls) 

	) &> build.out
	
	echo "$OUTPUT_DIR/$PKGNAME"
	popd &> /dev/null
done

