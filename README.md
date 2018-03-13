# d.sh

## Description
**d.sh** makes it easy to navigate the `$DIRSTACK` array in bash. It provides convenience functions to add/delete directories and to list the contents of `$DIRSTACK`.  
  
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
For a better tab completion experience, the `d cd` command only displays the
last subdirectory name. If the last subdirectory name is not unique all the
parent directory names, required to make a unique identifier, are displayed.
Running `d cd` with no parameter changes into the `$HOME` directory.

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

![d.sh in action](https://raw.githubusercontent.com/mscheufe/d.sh/master/screenshots/dsh_inaction.gif)

## Installation
Download the bash script

`curl https://raw.githubusercontent.com/mscheufe/d.sh/master/d.sh > ~/.d.sh`

Source it in your .bashrc

`source ~/.d.sh`

By default **d.sh** creates `d` as an alias to invoke the program. The alias can be changed by defining
the environment variable LEADER.
  
To map it to another character, like for instance a comma, add the below two lines to your .bashrc.

```
export LEADER=,
source ~/.d.sh
```

Now you can use it with `,` as key `,<space><tab><tab>`.
