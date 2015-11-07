
# Redis scan

We now know not to use `redis-cli keys` and especially not on production machines.

We should of course rather use `SCAN` (and `SSCAN` et al). Where the first line returned is the cursor for the next iteration.

Herewith a sample bash script to `SCAN` keys from Redis.

```shell
set -u 

tmp=tmp/scan
mkdir -p $tmp

c1scanned() {
  local key="$1"
  echo "scanned $key"
}

c1scan() {
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
