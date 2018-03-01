DIR_STORE=${DIR_STORE:-"${HOME}/.dir_store"}
LEADER=${LEADER:-","}

# colors
BLUE="\e[34;m"
RESCOL="\e[0m"

__dirstack::blue() { echo -en "$BLUE$*$RESCOL"; }

# populate $DIRSTACK from $DIR_STORE
__dirstack::populate() {
    local working_dir=${1:-$HOME}
    if [[ -f $DIR_STORE ]]; then
        # clear $DIRSTACK
        dirs -c
        while read dir; do
            [[ -d "$dir" ]] && pushd "$dir" >/dev/null
        done < <(sort -r $DIR_STORE)
        # add $working_dir to top of $DIRSTACK
        pushd $working_dir >/dev/null
        # remove $HOME from bottom of $DIRSTACK
        eval "popd +$(( ${#DIRSTACK[@]} - 1 )) >/dev/null"
    fi
}

# cd to the nth element in $DIRSTACK
dirstack::cd() { eval "cd ~$1"; }

# sort numeric parameters in desc order
__dirstack::sort() { echo "$*" | tr " " "\n" | sort -nr | tr "\n" " "; }

# parameter lists like 6 0 1-5 are expanded and sorted to 6 5 4 3 2 1
__dirstack::expandparams() {
    local _exp_params=""
    for i in $*; do
        if [[ $i =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local _values=$(eval "echo {${BASH_REMATCH[1]}..${BASH_REMATCH[2]}}")
            _exp_params="$_exp_params $_values"
        else
            _exp_params="$_exp_params $i"
        fi
    done
    __dirstack::sort $_exp_params
}

# rm nth element from $DIRSTACK
__dirstack::delete() {
    params=$(__dirstack::expandparams $*)
    for i in $params; do
        if [[ $i =~ ^[0-9]+$ && ! "${DIRSTACK[$i]}" = "" ]]; then
            popd +$i >/dev/null
        fi
    done
    dirs -l -p | awk 'NR > 1' | sort >$DIR_STORE
}

# prepend $PWD to relative path
__dirstack::prependpwd() {
    local path="$*"
    if [[ $path =~ ^\. ]]; then
        path=${path/./$PWD}
    elif [[ ! $path =~ ^\/|^\. ]]; then
        path="$PWD/$path"
    fi
    echo $path
}

# clears $DIRSTACK and wipes $DIR_STORE
dirstack::clear() {
    dirs -c
    cat /dev/null >$DIR_STORE
}

# rm nth element from $DIRSTACK and write to $DIR_STORE
dirstack::delete() { __dirstack::delete $*; dirstack::update; }

# add current directory to $DIRSTACK
dirstack::add() {
    echo $BASH_SUBSHELL
    if [[ "$PWD" != "$HOME" ]]; then
        awk 'NR > 1' <(dirs -l -p) <(echo $PWD) | sort | uniq >$DIR_STORE
    fi
}

# add all directories provided via STDIN to $DIRSTACK
dirstack::addmany() {
    local temp_1=$(mktemp)
    local temp_2=$(mktemp)
    while read dirname; do
        dirname=$(__dirstack::prependpwd "$dirname")
        if [[ -d "$dirname" ]]; then
            echo "$dirname"
        fi
    done </dev/stdin >$temp_1
    cat $temp_1 $DIR_STORE | sort | uniq >$temp_2
    rm $temp_1
    mv $temp_2 $DIR_STORE
}

# update $DIRSTACK from $DIR_STORE
dirstack::update() { __dirstack::populate "$PWD"; }

# list $DIRSTACK and add some color
dirstack::list() {
    while read pos dir; do
        echo -e " $(__dirstack::blue $pos) $dir"
    done < <(dirs -v -p | awk 'NR > 1')
}

alias ${LEADER}l="dirstack::list"
alias ${LEADER}a="dirstack::add; dirstack::update"
alias ${LEADER}am="dirstack::addmany; dirstack::update"
alias ${LEADER}g="dirstack::cd"
alias ${LEADER}c="dirstack::clear"
alias ${LEADER}u="dirstack::update"
alias ${LEADER}d="dirstack::delete"

dirstack::update
