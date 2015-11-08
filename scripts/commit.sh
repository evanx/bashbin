
cd ~/bashbin

if [ $# -eq 0 ]
then
  message="update"
elif [ $# -eq 1 ]
then
  message="$1"
else 
  echo "usage: single argument for commit message"
  exit 1
fi 

set -u

c0push() {
  echo
  pwd
  git add -A
  git commit -a -m "$message"
  git status
  git push 
}

c0push

