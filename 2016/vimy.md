
## What The File?

Sometimes on a specific host, we are most often editing a small subset of config files e.g. Nginx config files.

Let’s use bash auto completion!

Bash has a `complete` built-in to specify a "word list" for a specific command.

Let’s define a "completion" file containing the names of the files we commonly edit:
```shell
$ cat ~/.vimy.complete
~/.vimy.complete
/nginx-local/sites/redishub.com
```
where I have added the completion file itself too.

We drop the following lines into our `~/.bashrc` to alias `vi` to `vimy` and set its "word list" via `complete -W` as follows:
```shell
$ tail -2 ~/.bashrc
alias vimy=vi
complete -W "$(cat ~/.vimy.complete)" vimy
```

We re-import `.bashrc` into our current shell to test it immediately.
```shell
$ . ~/.bashrc
```

Now we try `vimy` and press Tab-Tab for auto-completion:
```
$ vimy (Tab Tab)
.vimy.wordlist.txt /nginx-local/sites/redishub.com
```

Done :)
