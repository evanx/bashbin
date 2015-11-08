
set -u # unset variable is an error

tmp=tmp/scan/$$ # create a tmp directory for this PID
mkdir -p $tmp

find tmp/scan -mtime +1 -exec rm {} \; # clean up previous

finish() {
  find tmp/scan/$$ # show the files created for debugging
  #rm -rf tmp/scan/$$ # alternatively remove tmp directory on exit 
}

trap finish EXIT

c1scanned() { # key: process a scanned key
  local key="$1"
  echo "scanned $key"
}

c1scan() { # match: scan matching keys, invoking c1scanned for each
  local match="$1"
  local cursor=0
  echo "match $match"
  while [ 1 ]
  do
    for key in `redis-cli scan $cursor match "$match" | tee $tmp/scan.out | tail -n +2`
    do
      c1scanned $key
    done
    cursor=`head -1 $tmp/scan.out`
    echo "cursor $cursor"
    if [ $cursor -eq 0 ]
    then
      break
    fi
  done
}

c0default() {
  c1scan 'article:*'
}

if [ $# -gt 0 ]
then
  command=$1
  shift
  c$#$command $@
else
  c0default
fi

