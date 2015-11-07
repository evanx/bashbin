
# Redis scan

```shell
c4scan() {
  key="$1"
  match="$2"
  count=$3
  cursor=0
}

c0default() {
  echo 'usage:'
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
