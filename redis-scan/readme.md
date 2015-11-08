
# Redis SCAN

So we should not to use `redis-cli keys` - especially not on large Redis instances on production machines. This can block Redis for a number of seconds.

We should of course rather use `SCAN` (and `SSCAN` et al). Where the first line returned is the cursor for the next iteration.

Herewith a sample bash script to `SCAN` keys from Redis.

### Housekeeping

Firstly some generic bash scripting housekeeping.

```shell
set -u # unset variable is an error

tmp=tmp/scan/$$ # create a tmp directory for this PID
mkdir -p $tmp

>&2 find tmp/scan -mtime +1 -exec rm {} \; # clean up previous older than 1 day

finish() { # EXIT trap to clean up
  >&2 find tmp/scan/$$ # show the files created for debugging
  #rm -rf tmp/scan/$$ # alternatively remove tmp directory on exit 
}

log() { # message: echo to stderr
  >&2 echo "$1"
}

trap finish EXIT
```
where `>&2` is used to redirect debugging info to stderr.


### SCAN

For each scanned matching key, we invoke a function `c1scanned` to perform some processing. In this example we just output the key to stdout. Which can redirect this output into a file.

```shell
c1scanned() { # key: process a scanned key
  local key="$1"
  log "scanned $key"
  echo "$key" # process this key
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
  done
}
```
where we `tee` the output to a file in order to extract the cursor from it's head for the next iteration. When the cursor returned is zero, we `break` from the `while` loop.


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
