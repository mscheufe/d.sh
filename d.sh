DIR_STORE=${DIR_STORE:-"${HOME}/.dir_store"}
LEADER=${LEADER:-","}

# colors
readonly RESET_COL='\033[m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RED='\033[0;31m'

_d::blue() { echo -en "$COLOR_BLUE$*$RESET_COL"; }
_d::red() { echo -en "$COLOR_RED$*$RESET_COL"; }

# reverse path
# $1=/dir1/dir2/dir3 ->  dir3 dir2 dir1
# $1=/dir1/space dir2/dir3 ->  dir3 space;dir2 dir1
_d::reverse_path() {
    local _path=${1#/}
    local IFS="/"
    local _split_path=($_path)
    local _rev_path=
    for _token in ${_split_path[@]}; do
        # replace all spaces with "," to avoid that
        # one path element is treated as two
        _rev_path="${_token// /,} $_rev_path"
    done
    echo ${_rev_path% }
}

# ckecks if $1 matches the end path pos $2 in ("$@")
_d::is_unique() {
    local _index=$1; shift
    local _regexp_path="/${1%/}$"; shift
    local _dirstack=("${@}")
    local _unique=0
    for _entry in "${_dirstack[@]}"; do
        if [[ $_entry != ${_dirstack[$_index]} ]]; then
            if [[ $_entry =~ $_regexp_path ]]; then
                _unique=1
            fi
        fi
    done
    echo $_unique
}

# determines all unique parts of the patch values contained in ("${@}")
_d::uniq_part_of_dir() {
    shift; local _dirstack=("${@}")
    local _uniq_dirs=()
    for _index in ${!_dirstack[@]}; do
        local _path_token=
        for _token in $(_d::reverse_path "${_dirstack[$_index]}"); do
            # replace "," with space to make matches possible
            _path_token="${_token//,/ }/$_path_token"
            local _unique=$(_d::is_unique $_index "$_path_token" "${_dirstack[@]}")
            if [[ $_unique -eq 0 || ${_dirstack[$_index]}/ = /$_path_token ]]; then
                _uniq_dirs[${#_uniq_dirs[@]}]=${_path_token%/}
                break
            fi
        done
    done
    # replace all spaces with ";" to avoid that
    # one dirstack element is treated as two
    echo "${_uniq_dirs[@]// /,}"
}

# populate $DIRSTACK from $DIR_STORE
_d::populate() {
    local working_dir=${1:-$HOME}
    if [[ -f $DIR_STORE ]]; then
        # clear $DIRSTACK
        dirs -c
        while read dir; do
            [[ -d "$dir" ]] && pushd "$dir" >/dev/null
        done < <(sort -r $DIR_STORE)
        # add $working_dir to top of $DIRSTACK
        pushd "$working_dir" >/dev/null
        # remove $HOME from bottom of $DIRSTACK
        eval "popd +$(( ${#DIRSTACK[@]} - 1 )) >/dev/null"
    fi
}

# sort numeric parameters in desc order
_d::sort() { echo "$*" | tr " " "\n" | sort -nr | tr "\n" " "; }

# parameter lists like 6 0 1-5 are expanded and sorted to 6 5 4 3 2 1
_d::expandparams() {
    local _exp_params=""
    for i in $*; do
        if [[ $i =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local _values=$(eval "echo {${BASH_REMATCH[1]}..${BASH_REMATCH[2]}}")
            _exp_params="$_exp_params $_values"
        else
            _exp_params="$_exp_params $i"
        fi
    done
    _d::sort $_exp_params
}

# rm nth element from $DIRSTACK
_d::delete() {
    params=$(_d::expandparams $*)
    for i in $params; do
        if [[ $i =~ ^[0-9]+$ && ! "${DIRSTACK[$i]}" = "" ]]; then
            popd +$i >/dev/null
        fi
    done
    dirs -l -p | awk 'NR > 1' | sort >$DIR_STORE
}

# prepend $PWD to relative pathes like ./<PATH> or <PATH>
_d::prependpwd() {
    local path="$*"
    if [[ $path =~ ^\. ]]; then
        path=${path/./$PWD}
    elif [[ ! $path =~ ^\/|^\. ]]; then
        path="$PWD/$path"
    fi
    echo $path
}

# add all directories provided via STDIN to $DIRSTACK
_d::addmany() {
    local temp_1=$(mktemp)
    local temp_2=$(mktemp)
    while read dirname; do
        dirname=$(_d::prependpwd "$dirname")
        if [[ -d "$dirname" ]]; then
            echo "$dirname"
        fi
    done </dev/stdin >$temp_1
    cat $temp_1 $DIR_STORE | sort | uniq >$temp_2
    rm $temp_1
    mv $temp_2 $DIR_STORE
}

# cd to the nth element in $DIRSTACK
d::cd() {
    (( ${#*} == 0 )) && { cd $HOME; return 0; }
    local err_msg=
    local err_regexp=".+$1:(.+)(out.+range)$"
    local dir_tilde_exp=$(dirs -l +$1 2>&1)
    if [[ $dir_tilde_exp =~ $err_regexp ]]; then
        err_msg="ERROR: ${BASH_REMATCH[1]} '$1' ${BASH_REMATCH[2]}"
        echo -e $(_d::red $err_msg)
    else
        if [[ -d $dir_tilde_exp ]]; then
            cd $dir_tilde_exp
        else
            err_msg="ERROR: directory '$dir_tilde_exp' does not exist"
            echo -e $(_d::red $err_msg)
        fi
    fi
}

# clears $DIRSTACK and wipes $DIR_STORE
d::clear() {
    dirs -c
    cat /dev/null >$DIR_STORE
}

# rm nth element from $DIRSTACK and write to $DIR_STORE
d::delete() { _d::delete $*; d::update; }

# add current directory to $DIRSTACK
d::add() {
    if [[ "$PWD" != "$HOME" ]]; then
        awk 'NR > 1' <(dirs -l -p) <(echo $PWD) | sort | uniq >$DIR_STORE
    fi
}

# add all directories available in $PWD
d::addmany() {
    find . -type d -depth 1 | _d::addmany
    d::update
}

# update $DIRSTACK from $DIR_STORE
d::update() { _d::populate "$PWD"; }

# list $DIRSTACK and add some color
d::list() {
    while read pos dir; do
        echo -e " $(_d::blue $pos) $dir"
    done < <(dirs -v -p | awk 'NR > 1')
}

alias ${LEADER}l="d::list"
alias ${LEADER}a="d::add; d::update"
alias ${LEADER}am="d::addmany"
alias ${LEADER}g="d::cd"
alias ${LEADER}c="d::clear"
alias ${LEADER}u="d::update"
alias ${LEADER}d="d::delete"

d::update
