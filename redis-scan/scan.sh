#!/bin/bash 

# housekeeping 

set -u # unset variable is an error

startTime=`date +%s`

log() { # echo to stderr
  >&2 echo "$*"
}

c2exit() {
  >&2 echo "exit $1: $2"
  exit $1
}

tmp=tmp/scan/$$ # create a tmp directory for this PID
mkdir -p $tmp
log "tmp $tmp"

>&2 find tmp/scan -mtime +1 -exec rm -rf {} \; # clean up previous older than 1 day

finish() {
  finishTime=`date +%s`
  log; log 'finish: duration (seconds)' `echo $finishTime - $startTime | bc`
  >&2 find tmp/scan/$$ # show the files created 
  rm -rf tmp/scan/$$ # remove tmp directory on exit 
}

trap finish EXIT 

# scan 

c1scanned() { # key: process a scanned key
  local key="$1"
  log "scanned: $key" 'load:' `cat /proc/loadavg | cut -f1 -d' '`
  echo "$key" # for example, just echo to stdout
  sleep .1 # sleep to alleviate the load on Redis and the server
}

c1scan() { # match: scan matching keys, invoking c1scanned for each
  local match="$1"
  local cursor=0
  while [ 1 ]
  do
    log; log "scan $cursor match $match"
    for key in `redis-cli scan $cursor match "$match" count 10 | tee $tmp/scan.out | tail -n +2`
    do
      c1scanned $key
    done
    cursor=`head -1 $tmp/scan.out`
    log "cursor $cursor"
    if [ $cursor -eq 0 ]
    then
      break
    fi
    sleep .1 # sleep to alleviate the load on Redis and the server
    while cat /proc/loadavg | grep -qv ^[01]
    do 
      log 'sleepload:' `cat /proc/loadavg | cut -f1 -d' '`
      sleep 5 # sleep while load is too high
    done 
  done
}


# command-line invocation 

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

