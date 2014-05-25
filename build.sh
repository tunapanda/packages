#!/bin/bash

DATESTAMP=$(date +%Y%m%d%H%M)
function defaults() {
	BASE_VERSION=1.0
	VERSION="${BASE_VERSION}-$DATESTAMP"
	ARCH="all"
}

# Define base working dir as parent of wherever this script lives.
# Uses a symlink-aware technique for finding script directory, originally from:
#   http://stackoverflow.com/questions/59895/
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
BASE_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
OUTPUT_DIR="$BASE_DIR/Packages"

if [ $# -eq 0 ]
then
	echo USAGE: $(basename $0) PACKAGE_DIR... >&2
	exit 1
fi

BUILT=""
for d in $@
do
	NAME=$(basename $d)
	unset PKGNAME
	defaults ; [ -e $d/build_overrides ] && . $d/build_overrides
	[ -z "$PKGNAME" ] && PKGNAME="${NAME}_${VERSION}_${ARCH}.deb"

	# Nothing to do if there's already a .deb and the 
	# directory hasn't been changed since it was created
	LATEST=$(ls -t $OUTPUT_DIR/${NAME}_*.deb 2>/dev/null | head -n1)
	# Apparently test isn't smart enough to not try the second half of a -a
	# pair if the first one fails. Hence the uglier looking &&'ded pair of test
	if $([ -n "$LATEST" ] && [ $(find $d/scripts $d/fs -newer $LATEST 2>/dev/null | wc -l) -eq 0 ])
	then
		continue
	fi
	
	# Everything from here on occurs in the package directory
	pushd $d &> /dev/null

	# For now we also can't continue unless there's an fs/ dir with files for the package
	[ -d fs ] || continue

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

