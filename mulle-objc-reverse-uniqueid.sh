#! /bin/sh
#
# (c) 2016 Mulle kybernetiK
# code by Nat!
#

#
# Search through sources to find a string for the given hash.
# It can be useful for optimized builds, where you do not have a reverse
# table in the runtime and the error message is just gives the uniqueid.
#

usage()
{
	cat <<EOF >&2
USAGE

mulle-objc-reverse-uniqueid.sh <uniqueid|command> [pattern] [paths]

uniqueid   the uniqueid to search, it may be partial

command    'words' or 'hashed-words', where
           'words' lists all words found in [paths] files matching [pattern]
           'hashed-words' is like 'words' but prefixes each line with
           the 64 bit uniqueid

pattern    filename pattern to search through, default is *.[hcm]

paths      paths to search *recursively* for files matching [pattern].
           It defaults to '.'. You can also use this to add more grep
           patterns and other grep flags.


EXAMPLE
           mulle-objc-reverse-uniqueid e37f0136 "*.h" /usr/local/include .

           check if the string "init" appears anywhere in the header
           files in /usr/local/include or the current directory.
EOF
	exit 1
}



HASH=$1
[ -z "$#" ] || shift

case "$HASH" in
	0x*)
		HASH="`echo "$HASH" | sed 's/^0x\(.*\)/\1/g'`"
		;;
esac
[ -z "${HASH}" ] && usage


PATTERN="${1:-*.[hcm]}"
[ -z "$#" ] || shift


PATHS="$*"
if [ -z "${PATHS}" ]
then
   PATHS="."
fi


grep -h -s -o -E '\w+' -r --include "${PATTERN}" ${PATHS} | \
   egrep -v '^[0-9]' | \
   sort | \
   sort -u | \
while read -r word
do
	case "${HASH}" in
		words)
	      echo "${word}"
	      ;;

		hashed-words)
			hash="`md5 -q -s "${word}" | cut -c1-16`"
	      echo "${hash} ${word}"
	      ;;

	   *)
			hash="`md5 -q -s "${word}" | cut -c1-16`"
			case "${hash}" in
				"${HASH}"*)
	   		 echo "${word}"
	      	;;
		   esac
		   ;;
	esac
done
