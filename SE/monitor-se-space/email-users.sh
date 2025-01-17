#!/bin/bash
# email-users.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support

help()
{   
  echo 
  echo "This script treats a file generated by monitor-se-space.sh (<SE_hostname>_users)"
  echo "and generates an email template to help VO support shifters send emails to heavy"
  echo "users of most loaded SEs."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] --users <user file> --unknown <unknown users files>"
  echo
  echo "  --vo <VO>: the Virtual Organisation. Defaults to biomed."
  echo
  echo "  --users <users file>: full name of the input file i.e. <SE_hostname>_users"
  echo
  echo "  --unknown <unknown users file>: full name of the input file i.e. <SE_hostname>_unknown"
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}

VO=biomed 

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    -h | --help ) help;;
    --users ) INPUTFILE=$2; shift ;;
    --unknown ) NOTFOUND=$2; shift ;;
    *) help ;;
  esac
  shift
done

if test -z "$INPUTFILE" ; then
    help
fi
if test -z "$NOTFOUND" ; then
    help
fi

SEHOSTNAME=`echo $INPUTFILE | sed "s/_users//" | awk -F"/" '{print $NF}'`

# Write the list of email addresses
echo -n "TO: biomed-technical-shifts@healthgrid.org;"
awk --field-separator "|" '{ printf " %s;",$2 }' $INPUTFILE
echo
cat <<EOF

SUBJECT: SE $SEHOSTNAME is full, please clean up or migrate your files

Dear $VO VO user,

You have stored more than 100 MB of files on SE $SEHOSTNAME, which is almost full. Please take some time to cleanup files you no longer need, or migrate them to some other SE. 

The list below shows all users with more than 100 MB on that SE. It also shows unknown users (no longer in the VO). If the users are/were part of your project or laboratory, please cleanup those files too or forward ths email to the appropriate person.

Please don't hesitate to contact us (biomed-technical-shifts@healthgrid.org) in case you experience difficulties in this process.

Also, note that it is not recommended to try to move many files in parallel: due to scalability issues of the SE, only a limited number of concurrent connections can be initiated.

Thanks in advance,
   The $VO technical support team.

EOF

echo "#----------------------------------------------------------------------------------"
echo "# User's DN                                                         Used space (GB)" 

awk --field-separator "|" '{ printf "%-70s %11s\n",$1,$3; }' $INPUTFILE

if test -f $NOTFOUND; then
  echo
  echo "# Unknwon users (no longer in the VO)"
  awk --field-separator "|" '{ printf "%-70s %11s\n",$1,$2; }' $NOTFOUND
fi

