
# Redis SCAN

So we should not use `redis-cli keys` - especially not on large Redis keyspaces on production machines. This can block Redis for a number of seconds.

We should of course rather use the `SCAN` command (and SSCAN et al). Where the first line returned is the cursor for the next iteration.

Herewith a sample bash script to `SCAN` keys from Redis:

https://github.com/evanx/bashbin/blob/master/redis-scan/scan.sh

This is a useful template for scanning in bash scripts that perform the following use-cases:
- change the EXPIRE/TTL
- pruning e.g. deleting keys according to their TTL or other logic
- migrating keys to another Redis instance
- archiving Redis content to a disk-based database

Incidently one of our use-cases, is extracting static JSON content to a disk where it can be served directly by Nginx's `try_files` and otherwise proxy to the "upstream" service. We can then expire and prune those particular Redis keys more aggressively, since existing content will be served off disk by Nginx - even when the upstream service is down or being restarted.


### Housekeeping

Firstly some generic bash scripting housekeeping.

```shell
set -u # unset variable is an error

log() { # message: echo to stderr
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

startTime=`date +%s`

finish() { # EXIT trap to clean up
  finishTime=`date +%s`
  log 'finish: duration (seconds)' `echo $finishTime - $startTime | bc`
  >&2 find tmp/scan/$$ # show the files created
  rm -rf tmp/scan/$$ # remove tmp directory on exit
}

trap finish EXIT
```
where `>&2` is used to redirect debugging info to stderr. (We can hide the debugging info by redirecting `2>/dev/null` when running the script.)

In general it's useful to have a "tmp" directory for each bash script. We create a dedicated directory according to its PID i.e. `$$`



### Sleep to alleviate load

Since we do not wish to overload the system, we generally take the approach of sleeping when the load is too high.

```shell
c0sleepload() # sleep if load is too high
  while cat /proc/loadavg | grep -qv ^[0-1]
  do
    log 'sleepload:' `cat /proc/loadavg | cut -f1 -d' '`
    sleep 15
  done
}

```

While the current loadavg is 2 or greater, we'll sleep until it settles below 2 again.


### Scan

We `tee` the output of `redis-cli scan` to a file in order to extract the cursor from it's head for the next iteration. We loop through the keys, skipping the first line (which is the returned cursor).

```shell
c1scan() { # match: scan matching keys, invoking c1scanned for each
  local match="$1"
  local cursor=0
  log "scan: match $match"
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
    c0sleepload # sleep if load is too high
  done
}
```
When the cursor returned is zero, we `break` from the `while` loop.

Note we are using the default scan count of 10 keys per iteration.


### Scanned

For each matching key, we invoke a function `c1scanned` to perform some processing.

```shell
c1scanned() { # key: process a scanned key
  local key="$1"
  log "scanned $key" 'load:' `cat /proc/loadavg | cut -f1 -d' '`
  echo "$key" # process this key
  sleep .1 # sleep to alleviate the load on Redis and the server
}
```

In this example we just output the key to stdout, i.e. equivalent to the `redis-cli keys` command.

In practice, we may be issuing Redis commands here to check TTL, delete, migrate or archive keys.

Note that we take care to sleep, so that we are not hogging Redis. If our processing is quite intensive, we might increase the sleep duration appropriately.

Having said that, we are using the default scan count of 10 keys, and sleeping in the outer `while` loop i.e. after processing every 10 keys, which should be sufficient.


### Commands

Incidently, we use a custom "command" notation where function names are prefixed by a `c` and the number of arguments they expect.

```shell
c0default() {
  c1scan 'article:*' # match
}

if [ $# -gt 0 ]
then
  command=$1
  shift
  c$#$command $@
else
  c0default
fi
```
where `c0default` is invoked when no command-line arguments are given.


This enables us to invoke specific functions as "commands" from the command-line, to make the bash script more useful and debuggable.

```shell
evans@boromir:~/bashbin/redis-scan$ bash scan.sh scan 'article:*'
tmp tmp/scan/22088
match article:*
scanned article:1934123 load: 0.21
article:1934123
...
finish: duration (seconds) 5
tmp/scan/22088
tmp/scan/22088/scan.out
```

where two command-line arguments are specified i.e. `scan` and `article:*` - so we invoke the function `c1scan` i.e. with 1 argument i.e. `'article:*'` (the MATCH parameter for the SCAN command)

https://twitter.com/@evanxsummers
