#!/bin/bash
# se-heavy-users.sh, v1.1
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This script looks for users who have more that 100 MB of data on the given SE.
# It provides the list of such users as well as their email address.
#
# All parameters default to biomed specific values, but can be specified using the options.

VO=biomed
WDIR=`pwd`
RESDIR=`pwd`
VOMS_USERS=$WDIR/voms-users.txt
USER_MIN_SPACE=0.1

help()
{
  echo
  echo "This script looks for users of the given VO who have more that 100 MB of data on the given SE."
  echo "It provides the list of such users as well as their email address."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--voms-users <file name>] [--user-min-used  <space in GB>]"
  echo "          [--work-dir <work directory>] [--result-dir <result directory>] <SE hostname>"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --voms-users <file name>: list of users extracted from the VOMS server."
  echo "          Defaults to './voms-users.txt'."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. Defaults to '.'."
  echo
  echo "  --result-dir <result directory>: where to store result files, that is <hostname>_email."
  echo "          Defaults to '.'."
  echo
  echo "  --user-min-used <space in GB>: minimum used space (in GB) for a user to be reported. Defaults to 0.1 = 100 MB."
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}

# Check environment
if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
MONITOR_SE_SPACE=$VO_SUPPORT_TOOLS/SE/monitor-se-space
LFC_BROWSE_SE_BIN=$VO_SUPPORT_TOOLS/SE/lfc-browse-se/LFCBrowseSE

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --voms-users ) VOMS_USERS=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --user-min-used ) USER_MIN_SPACE=$2; shift;;
    -h | --help ) help;;
    *) SEHOSTNAME=$1;;
  esac
  shift
done
if test -z "$SEHOSTNAME" ; then
    help
fi

#--- Check additional environment
if test -z "$LFC_HOST"; then
    echo "Please set variable LFC_HOST before calling $0, e.g. export LFC_HOST=lfc-biomed.in2p3.fr"
    exit 1
fi
if ! [ -d $WDIR ]; then
    mkdir -p $WDIR
fi

mkdir -p $WDIR/tmp
LBS_OUT=$WDIR/tmp/$SEHOSTNAME.lst

#--- The hostname_status file will help display the status of the analysis on the web report
RESULT_STATUS=$RESDIR/${SEHOSTNAME}_status
echo "${SEHOSTNAME}|ongoing" | awk --field-separator "|" '{ printf "%-50s %s\n",$1,$2; }' > $RESULT_STATUS

#--- Process the SE: get all VO users having files there
touch $LBS_OUT
echo -n "# Starting LFCBrowseSE at " >> $LBS_OUT
DATE_FORMAT="+%Y-%m-%d %H:%M:%S %Z"
date "$DATE_FORMAT" >> $LBS_OUT

$LFC_BROWSE_SE_BIN $SEHOSTNAME --vo $VO --summary 2>&1 >> $LBS_OUT

echo -n "# LFCBrowseSE completed at " >> $LBS_OUT
date "$DATE_FORMAT" >> $LBS_OUT

#--- For each user with more than x GB, get his email address from the VOMS
RESULT=$WDIR/${SEHOSTNAME}_users
NOTFOUND=$WDIR/${SEHOSTNAME}_unknown

TMP_PARSE_AWK=$WDIR/parse-lfcbrowsese.awk
sed "s/@SPACE_THRESHOLD@/$USER_MIN_SPACE/" $MONITOR_SE_SPACE/parse-lfcbrowsese.awk.tpl > $TMP_PARSE_AWK

awk -f $TMP_PARSE_AWK $LBS_OUT | while read LINE ; do
  dn=`echo $LINE | cut -d"|" -f1`
  used=`echo $LINE | cut -d"|" -f2`

  voms_user=`grep "$dn" $VOMS_USERS`
  if test $? -eq 0; then
    # Get the user's email address
    echo -n "$dn|"  >> $RESULT
    # Complex parsing due to several ambiguous separators: <user's dn>, <CA dn> - <email address>
    echo -n $voms_user | awk '{ printf "%s", gensub("^.+ - ([^ ]+@[^ ]+)$", "\\1", 1); }' >> $RESULT
    echo "|$used"  >> $RESULT
  else
    echo "$dn|$used" >> $NOTFOUND
  fi
done

#--- Convert the result into a file preparing the email to send to users
RESULT_EMAIL=$RESDIR/${SEHOSTNAME}_email
mkdir -p $RESDIR
$MONITOR_SE_SPACE/email-users.sh --vo $VO --users $RESULT --unknown $NOTFOUND > $RESULT_EMAIL

#--- Export the result file to the result dir in a more readable form
awk --field-separator "|" '{ printf "%-70s %11s\n",$1,$3; }' $RESULT > $RESDIR/${SEHOSTNAME}_users

#--- Export the list of unkown users to the result dir in a more readable form
if test -f $NOTFOUND; then
  awk --field-separator "|" '{ printf "%-70s %11s\n",$1,$2; }' $NOTFOUND > $RESDIR/${SEHOSTNAME}_unknown
fi

#--- Make the final status line giving the used space percentage and the link to the list of users
USED_PERCENT=`lcg-infosites --vo $VO space | awk -f $VO_SUPPORT_TOOLS/SE/show-se-space/parse-lcg-infosites-space.awk | grep "^$SEHOSTNAME" | cut -d" "  -f5`
echo "${SEHOSTNAME}|${USED_PERCENT}% full," | awk --field-separator "|" '{ printf "<a href=\"#%s\">%-51s</a>, %10s completed.\n",$1,$1,$2; }' > $RESULT_STATUS

rm -f $TMP_PARSE_AWK

