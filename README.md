# d.sh

## Description
**d.sh** makes use of the `$DIRSTACK` array in bash to easy add, delete and navigate directories.  
**d.sh** supports tab completion. To see all possible commands type `d<space><tab><tab>`  

```
list           display $DIRSTACK
cd             cd to th directory in $DIRSTACK <tab complete>
add            add $PWD to $DIRSTACK
addirs         add directories in $PWD to $DIRSTACK
del_byname     delete directory from $DIRSTACK by name <tab complete>
del_byindex    delete directory from $DIRSTACK by index
update         read $DIR_STORE and update $DIRSTACK
clear          wipe $DIRSTACK and $DIR_STORE
```

### Additional information
For a better tab completion experience the `d cd` command only displays the
last sub directory name. If the last sub directory name is not unique all the
parent directory names, required to make an unique identifier, are displayed.

The `d del_byindex` command accepts index numbers to delete directories from
`$DIRSTACK`.  It is also possible to provide a list of index numbers ordered or
unordered, a range of index numbers and a mix of both.

The following are all valid `d del_byindex` commands:

* `d del_byindex 1`
* `d del_byindex 1 2 3`
* `d del_byindex 4-6`
* `d del_byindex 1 2 3 4-6`
* `d del_byindex 2 4-6 1 3`
* `d del_byindex 2 6-4 1 3`

## Installation
Download the bash script

`curl https://raw.githubusercontent.com/mscheufe/d.sh/master/d.sh > ~/.d.sh`

Source it in your .bashrc

`source ~/.d.sh`

By default d.sh binds d::main to the key "d" by adding an alias to the environment.
In case you want to bind it to something else add the environment variable
LEADER with your preferred key.

To bind it to another key like for instance "," add the below two lines to your .bashrc.

```
export LEADER=,
source ~/.d.sh
```
