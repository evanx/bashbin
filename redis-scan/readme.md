
# Redis scan

So we should not to use `redis-cli keys` - especially not on large Redis instances on production machines. This can block Redis for a number of seconds.

We should of course rather use `SCAN` (and `SSCAN` et al). Where the first line returned is the cursor for the next iteration.

Herewith a sample bash script to `SCAN` keys from Redis.

Firstly some generic bash scripting housekeeping.

```shell
set -u # unset variable is an error

tmp=tmp/scan/$$ # create a tmp directory for this PID
mkdir -p $tmp

find tmp/scan -mtime +1 -exec rm {} \; # clean up previous 

finish() {
  find tmp/scan/$$ # show the files created for debugging
  #rm -rf tmp/scan/$$ # alternatively remove tmp directory on exit 
}

trap finish EXIT
```

### SCAN

For each scanned matching key, we invoke a function `c1scanned` where we perform some processing.


```
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
```
where we `tee` the output to a file in order to extract the cursor from it's head for the next iteration. When the cursor returned is zero, we `break` from the infinite `while` loop.


### Commands 

Incidently, we use our own "command" notation where functions are prefixed by a `c` and the number of arguments they expect.

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

This enables us to invoke specific functions (with arguments) from the command-line e.g. for debugging purposes.

```
evans@boromir:~/bashbin/redis-scan$ sh scan.sh scan 'article:*' | head -2
match article:*
scanned article:1940344:hashes
```

where the function `c1scan` will be invoked in this case since the "command" given (as the first command-line argument) is "scan," and there is one argument for that viz. `article:*`
