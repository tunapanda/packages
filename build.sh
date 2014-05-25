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
	OUTPUT_DIR="$BASE_DIR/Packages"
	[ -e $BASE_DIR/build_overrides ] && . $BASE_DIR/build_overrides 	
}


if [ $# -eq 0 ]
then
	echo USAGE: $(basename $0) PACKAGE_DIR... >&2
	exit 1
fi

BUILT=""
for d in $@
do
	# For now the build script can only handle package dirs with an
	# fs/ subdir with files for the package
	[ -d $d/fs ] || continue

	# Set package-specific options
	unset PKGNAME
	defaults ; [ -e $d/build_overrides ] && . $d/build_overrides
	[ -z "$NAME" ] && NAME=$(basename $d)

	# Nothing to do if there's already a .deb and the 
	# directory hasn't been changed since it was created
	EXISTING=$( find $OUTPUT_DIR  -regex '.*/'${NAME}'_'${VERSION}'\(-[0-9]+\)?_[^/]*.deb$' )
	if [ -n "$EXISTING" ]
	then
		LATEST=$(ls -lt $EXISTING | head -n1)
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
		CMD="fpm -s dir -t deb -C fs -a $ARCH -n $NAME -v $VERSION $SCRIPTS -p $OUTPUT_DIR/$PKGNAME $(cd fs; ls)" 
		echo "== RUNNING $CMD"
		$CMD
	) &> build.out
	
	echo "$OUTPUT_DIR/$PKGNAME"
	popd &> /dev/null
done

