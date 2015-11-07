
# Redis scan

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
```

