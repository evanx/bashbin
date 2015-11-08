#!/bin/bash 

# housekeeping 

set -u # unset variable is an error

log() { # echo to stderr
  >&2 echo "$*"
}

c2exit() {
  >&2 echo "EXIT $*"
  exit $1
}

lhost=`hostname -s`
tmpHashes="tmp:scan:$lhost:$$:hashes" # a tmp redis hashes key for general use by this script
log "tmpHashes $tmpHashes"

c1tmp_pipe() {
  tr -d '\n' | redis-cli -n 13 -x hset $tmpHashes $1 >/dev/null
}

c1tmp_get() {
  redis-cli --raw -n 13 hget $tmpHashes $1
}

date +%s | c1tmp_pipe time # set run start time field in tmp hashes 
c1tmp_get time | grep -q '^[0-9][0-9]*$' || c2exit 1 'tmp hashes time' # set run start time from tmp hashes
redis-cli -n 13 expire $tmpHashes 129600 >/dev/null # expire tmp redis hashes in 36 hours

tmp=tmp/scan/$$ # create a tmp directory for this PID
mkdir -p $tmp

log "tmp $tmp"

#>&2 find tmp/scan -mtime +1 -exec rm -rf {} \; # clean up previous older than 1 day

finish() {
  echo `date +%s` - `c1tmp_get time` | bc | c1tmp_pipe duration
  log; log; log "finish: duration (seconds)" `c1tmp_get duration`
  >&2 redis-cli -n 13 hgetall $tmpHashes
  redis-cli -n 13 expire $tmpHashes 60 >/dev/null # expire tmp redis hashes in 60 seconds
  >&2 log $tmpHashes `redis-cli -n 13 hkeys $tmpHashes` # show the tmp hashes for debugging
  >&2 find tmp/scan/$$ # show the files created for debugging
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

