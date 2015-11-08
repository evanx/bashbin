#!/bin/bash 

# housekeeping 

set -u # unset variable is an error

log() { # echo to stderr
  >&2 echo "$*"
}

tmp=tmp/scan/$$ # create a tmp directory for this PID
mkdir -p $tmp

log "tmp $tmp"

>&2 find tmp/scan -mmin +5 -exec rm -rf {} \; # clean up previous older than 5 mins

finish() {
  >&2 find tmp/scan/$$ # show the files created for debugging
  rm -rf tmp/scan/$$ # remove tmp directory on exit 
}

trap finish EXIT


# scan 

c1scanned() { # key: process a scanned key
  local key="$1"
  log "scanned $key"
  echo "$key" # for example, just echo to stdout
}

c1scan() { # match: scan matching keys, invoking c1scanned for each
  local match="$1"
  local cursor=0
  log "match $match"
  while [ 1 ]
  do
    for key in `redis-cli scan $cursor match "$match" | tee $tmp/scan.out | tail -n +2`
    do
      c1scanned $key
    done
    cursor=`head -1 $tmp/scan.out`
    log "cursor $cursor"
    if [ $cursor -eq 0 ]
    then
      break
    fi
    sleep .1 # sleep for 100ms to manage the load on Redis and the server
    while cat /proc/loadavg | grep -qv ^[0-1]
    do 
      sleep 1 # sleep while load is too high
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


