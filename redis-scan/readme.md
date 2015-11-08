
# Redis SCAN

So we should not to use `redis-cli keys` - especially not on large Redis instances on production machines. This can block Redis for a number of seconds.

We should of course rather use `SCAN` (and `SSCAN` et al). Where the first line returned is the cursor for the next iteration.

Herewith a sample bash script to `SCAN` keys from Redis.

### Housekeeping

Firstly some generic bash scripting housekeeping.

```shell
set -u # unset variable is an error

log() { # message: echo to stderr
  >&2 echo "$1"
}

tmp=tmp/scan/$$ # create a tmp directory for this PID
mkdir -p $tmp
log "tmp $tmp"

finish() { # EXIT trap to clean up
  >&2 find tmp/scan/$$ # show the files created for debugging
  rm -rf tmp/scan/$$ # alternatively remove tmp directory on exit 
}

trap finish EXIT
```
where `>&2` is used to redirect debugging info to stderr. We suppress the debugging of the script via `2>/dev/null`


### Sleep to alleviate load 

Since we do not wish to overload the system, we generally take the approach of sleeping when the load is too high.

```shell
c0sleepload() # sleep if load is too high
  while cat /proc/loadavg | grep -qv ^[0-1]
  do 
    log 'sleep' 'load:' `cat /proc/loadavg | cut -f1 -d' '`
    sleep 5 # sleep while load is high
  done 
}

```

While the `loadavg` is `2` or greater, we'll sleep until it settles beflow 2 again.

### SCAN

For each scanned matching key, we invoke a function `c1scanned` to perform some processing. In this example we just output the key to stdout, i.e. equivalent to `redis-cli keys`

```shell
c1scanned() { # key: process a scanned key
  local key="$1"
  log "scanned $key" 'load:' `cat /proc/loadavg | cut -f1 -d' '`
  echo "$key" # process this key
  sleep .1 # sleep to alleviate the load on Redis and the server
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
    c0sleepload # sleep if load is too high
  done
}
```
where we `tee` the output to a file in order to extract the cursor from it's head for the next iteration. When the cursor returned is zero, we `break` from the `while` loop.

Note that we take care to sleep to alleviate the load on Redis and the server. If our processing is quite intensive, we should increase the duration appropriately.

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


This enables us to invoke specific functions (with arguments) from the command-line, to make the bash script more useful and debuggable.

```shell
evans@boromir:~/bashbin/redis-scan$ bash scan.sh scan 'article:*'
match article:*
scanned article:1940344
...
```

where two command-line arguments are specified viz. `scan` and `article:*` - so we invoke the function `c1scan` wth argument `article:*`
