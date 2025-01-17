#!/bin/bash
# monitor-se-space.sh, v1.1
# Author: F. Michel, CNRS I3S, biomed VO support
#
# Algo:
#   Get the list of SEs sorted by %age of used space
#   Select only SEs with used space over $SPACE_THRESHOLD
#   For each one:
#      Run the LFCBrosweSE tool to get the list of users (summary)
#      For each user above a given threshold
#         Get user's email address from the VOMS server
#         Send a mail notification


# Default threshold of used space over which to analyse an SE
SPACE_THRESHOLD=95
USER_MIN_SPACE=0.1

NOW=`date "+%Y%m%d-%H%M%S"`
NOW_PRETTY=`date`
WDIR=`pwd`/$NOW
RESDIR=`pwd`/$NOW

VO=biomed
VOMS_USERS=`pwd`/voms-users.txt

help()
{
  echo
  echo "This script monitors the free space the SEs supporting a given VO."
  echo "For all SEs with more than 95% space used, it runs the LFCBrowseSE tool to"
  echo "collect the VO users who have more than 100 MB of data on that SE, then"
  echo "produces the list of DNs, used space, and email addresses of those users."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--voms-users <file name>] [--threshold <percentage>] [--user-min-used  <space in GB>]"
  echo "               [--work-dir <work directory>] [--result-dir <result directory>]"  
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --voms-users <file name>: list of users extracted from the VOMS server."
  echo "           Defaults to './voms-users.txt'."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. The date is appended to the directory,"
  echo "           formatted as <work directory>/YYYYMMDD-HHMMSS. Defaults to './<date>'."
  echo
  echo "  --result-dir <result directory>: where to store result files, that is <hostname>_email."
  echo "           The date is appended to the directory, formatted as <result directory>/YYYYMMDD-HHMMSS."
  echo "           Defaults to './<date>'."
  echo
  echo "  --threshold <percentage>: percentage of used space over which a SE will be monitored. Defaults to 95."
  echo
  echo "  --user-min-used <space in GB>: minimum used space (in GB) for a user to be reported. Defaults to 0.1 = 100 MB."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Examples:"
  echo "Check SEs supporting biomed with used space over 95%, users with more than 100 MB, store temp and result files in current directory.<date>:"
  echo "   $0"
  echo
  echo "Check SEs supporting VO myVO with used space over 90%"
  echo "   ./monitor-se-space.sh --vo myVo --threshold 90"
  echo "                         --voms-users /tmp/monitor-se/voms-users.txt"
  echo "                         --work-dir /tmp/monitor-se"
  echo '                         --result-dir $HOME/public_html/monitor-se'
  echo
  exit 1
}

# Check environment
if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
MONITOR_SE_SPACE=$VO_SUPPORT_TOOLS/SE/monitor-se-space
SHOW_SE_SPACE=$VO_SUPPORT_TOOLS/SE/show-se-space

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --voms-users ) VOMS_USERS=$2; shift;;
    --work-dir ) WDIR=$2/$NOW; shift;;
    --result-dir ) RESDIR=$2/$NOW; shift;;
    --threshold ) SPACE_THRESHOLD=$2; shift;;
    --user-min-used ) USER_MIN_SPACE=$2; shift;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done


mkdir -p $WDIR

# Apply the awk template to have the proper filter of %age of used space
TMP_PARSE_AWK=$WDIR/parse-show-se-space.awk
sed "s/@SPACE_THRESHOLD@/$SPACE_THRESHOLD/" $MONITOR_SE_SPACE/parse-show-se-space.awk.tpl > $TMP_PARSE_AWK

# Make the list of SEs that use space over the given threshold (95% by default)
TMP_LIST_SE=$WDIR/list-se.txt
#$SHOW_SE_SPACE/show-se-space.sh --vo $VO --sort %used --reverse --max 30 --no-header --no-sum | awk -f $TMP_PARSE_AWK | sort | uniq > $TMP_LIST_SE
$SHOW_SE_SPACE/show-se-space.sh --vo $VO --sort %used --reverse --no-header --no-sum | awk -f $TMP_PARSE_AWK | sort | uniq > $TMP_LIST_SE

# Prepare web report with a title, threshold of used space and date/time
mkdir -p $RESDIR
cat <<EOF >> $RESDIR/INFO.htm
Report started $NOW_PRETTY<br>
SE minimum used space: ${SPACE_THRESHOLD}%<br>
Users minimum used space: ${USER_MIN_SPACE}GB
EOF

# Run the analisys on each SE in parallel
echo "Starting analysis of SEs over ${SPACE_THRESHOLD}% of used space, reporting uses consumming over ${USER_MIN_SPACE}GB - $NOW_PRETTY"
for SEHOSTNAME in `cat $TMP_LIST_SE`
do
  echo "$SEHOSTNAME"
  $MONITOR_SE_SPACE/se-heavy-users.sh --vo $VO --voms-users $VOMS_USERS --user-min-used $USER_MIN_SPACE --work-dir $WDIR --result-dir $RESDIR $SEHOSTNAME &
  sleep 10
done
echo "Analysis started."

# Clean up
#rm -f $TMP_LIST_SE
rm -f $TMP_PARSE_AWK


