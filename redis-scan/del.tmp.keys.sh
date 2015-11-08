

  cursor=0
  while [ 1 ]
  do
    for key in `redis-cli scan $cursor match 'tmp:*' | tail -n +2`
    do 
      echo $key
      redis-cli del $key
      sleep .1
    done
    cursor=`redis-cli scan $cursor match 'tmp:*' | head -1`
    [ $cursor -gt 0 ] || break
    sleep .01
  done
