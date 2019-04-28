#!/usr/bin/env bash
# shellcheck disable=2164
DIR_STORE=${DIR_STORE:-"${HOME}/.dir_store"}
LEADER=${LEADER:-"d"}

# colors
readonly D_RESET_COL='\033[m'
readonly D_COLOR_BLUE='\033[0;34m'
readonly D_COLOR_RED='\033[0;31m'
readonly D_COLOR_MAGENTA='\033[0;35m'

_d::blue() { echo -en "$D_COLOR_BLUE$*$D_RESET_COL"; }
_d::red() { echo -en "$D_COLOR_RED$*$D_RESET_COL\n"; }
_d::magenta() { echo -en "$D_COLOR_MAGENTA$*$D_RESET_COL"; }

# bash version 4 is required
(( ${BASH_VERSION:0:1} < 4 )) && { _d::red "bash version 4 is required"; exit 1; }

# reverse a path string
# /dir0/dir1/dir2 => dir2\\ndir1\\ndir0\\n
_d::reverse_path() {
    [[ -n ${1##*/} ]] && printf '%s\n' "${1##*/}"
    [[ -z "${1%/*}" ]] && return 1
    _d::reverse_path "${1%/*}"
}

# if only one path in $DIRSTACK ends with $1 return 0 otherwise 1
_d::is_uniq() {
    local _pattern="$1"; shift
    [[ $(printf "%s\n" "$@" | sed -n "\#$_pattern\$#p" | wc -l) -gt 1 ]] && return 1
    return 0
}

# determines all unique parts of the path values contained in ("${@}")
_d::uniq_part_of_dir() {
    shift; local _dirstack=("$@")
    while read -r line; do
        local _uniq_part=
        while read -r token; do
            _uniq_part="${token}/${_uniq_part}"
            if _d::is_uniq "/${_uniq_part%/}" "${_dirstack[@]}"; then
                echo "${_uniq_part%/}"
                unset _uniq_part
                break
            fi
        done < <(_d::reverse_path "$line")
        [[ -n "$_uniq_part" ]] && echo "${_uniq_part%/}"
    done < <(printf "%s\n" "${_dirstack[@]}")
}

# get all unique parts of the pathes stored in $DIRSTACK
_d::uniq_dir_parts() { _d::uniq_part_of_dir "${DIRSTACK[@]}"; }

# populate $DIRSTACK from $DIR_STORE
_d::populate() {
    local working_dir=${1:-$HOME}
    if [[ -f $DIR_STORE ]]; then
        # clear $DIRSTACK
        dirs -c
        while read -r dir; do
            [[ -d "$dir" ]] && pushd "$dir" >/dev/null
        done < <(sort -r "$DIR_STORE")
        # add $working_dir to top of $DIRSTACK
        pushd "$working_dir" >/dev/null
        # remove last entry from $DIRSTACK ($working_dir)
        eval "popd +$(( ${#DIRSTACK[@]} - 1 )) >/dev/null"
    fi
}

# sort numeric parameters in desc order
_d::sort() { local _s= ;_s=$(echo "$*" | tr ' ' '\n' | sort -nr | tr '\n' ' '); echo -n "${_s% }"; }

# parameter lists like 6 0 1-5 are expanded and sorted to 6 5 4 3 2 1
_d::expandparams() {
    local _exp_params=
    local _params=
    read -ra _params <<<"$1"
    for i in "${_params[@]}"; do
        if [[ $i =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local _values=
            _values=$(eval "echo {${BASH_REMATCH[1]}..${BASH_REMATCH[2]}}")
            _exp_params="$_exp_params $_values"
        else
            [[ $i =~ ^[0-9]+$ ]] && _exp_params="$_exp_params $i"
        fi
    done
    _d::sort "${_exp_params# }"
}

# rm nth element from $DIRSTACK
_d::delete() {
    [[ "$*" = "" ]] && { echo -e "$(_d::red "to delete, select a directory")"; return 1; }
    params=$(_d::expandparams "$*")
    for i in $params; do
        if [[ $i =~ ^[0-9]+$ && ! "${DIRSTACK[$i]}" = "" ]]; then
            popd "+$i" >/dev/null
        fi
    done
    dirs -l -p | awk 'NR > 1' >"$DIR_STORE"
}

# prepend $PWD to relative pathes like ./<PATH> or <PATH>
_d::prependpwd() {
    local path="$*"
    if [[ $path =~ ^\. ]]; then
        path=${path/./$PWD}
    elif [[ ! $path =~ ^/|^\. ]]; then
        path="$PWD/$path"
    fi
    echo "$path"
}

# add all directories provided via STDIN to $DIRSTACK
_d::addmany() {
    local temp_1
    local temp_2
    temp_1=$(mktemp)
    temp_2=$(mktemp)
    while read -r dirname; do
        dirname=$(_d::prependpwd "$dirname")
        if [[ -d "$dirname" ]]; then
            echo "$dirname"
        fi
    done </dev/stdin >"$temp_1"
    cat "$temp_1" "$DIR_STORE" | sort | uniq >"$temp_2"
    rm "$temp_1"
    mv "$temp_2" "$DIR_STORE"
}

# returns position of dir_name in $DIRSTACK
_d::get_pos_in_stack() {
    local dir_name="$*"
    while read -r _pos _dir; do
        if [[ $_dir =~ /${dir_name}$ ]]; then
            echo "$_pos"
            break
        fi
    done < <(d::list)
}

# convert $BASH_VERSION to int
_d::bash_ver_toint() { local _ver="${BASH_VERSION::6}"; echo "${_ver//./}"; }

# split directory path into its subdirectories
_d::split_into_subdirs() { local _a="${1#/}"; _a=${_a%/}; echo -e "${_a//\//\\n}"; }

# trims path $1 that it ends with subdirectory $2
_d::trim_path() {
    local _parent=${1%/*}
    [[ -z "$_parent" ]] && return 0
    [[ "${_parent##*/}" = "$2" ]] && { echo "$_parent"; return 0; }
    _d::trim_path "$_parent" "$2"
}

# cd to the nth element in $DIRSTACK
d::cd() {
    [[ "$*" = "" ]] && { cd "$HOME"; return 0; }
    local err_msg=
    local err_regexp=".+$1:(.+)(out.+range)$"
    local dir_tilde_expanded=
    dir_tilde_expanded=$(dirs -l "+$1" 2>&1)
    if [[ $dir_tilde_expanded =~ $err_regexp ]]; then
        err_msg="ERROR: ${BASH_REMATCH[1]} '$1' ${BASH_REMATCH[2]}"
        echo -e "$(_d::red "$err_msg")"
    else
        if [[ -d $dir_tilde_expanded ]]; then
            cd "$dir_tilde_expanded"
        else
            err_msg="ERROR: directory '$dir_tilde_expanded' does not exist"
            echo -e "$(_d::red "$err_msg")"
        fi
    fi
}

# clears $DIRSTACK and wipes $DIR_STORE
d::clear() { dirs -c; cat /dev/null >"$DIR_STORE"; }

# rm nth element from $DIRSTACK and write to $DIR_STORE
d::delete() { _d::delete "$*"; d::update; }

# add current directory to $DIRSTACK
d::add() {
    if [[ "$PWD" != "$HOME" ]]; then
        awk 'NR > 1' <(dirs -l -p) <(echo "$PWD") | sort | uniq >"$DIR_STORE"
    fi
}

# add all directories available in $PWD
d::addmany() { find "$PWD" -maxdepth "1" -mindepth "1" -type "d" | _d::addmany; }

# update $DIRSTACK from $DIR_STORE
d::update() { _d::populate "$PWD"; }

# list $DIRSTACK
d::list() { dirs -v -p | awk 'NR > 1'; }

d::up() { cd "$(_d::trim_path "$PWD" "$*")"; }

# list $DIRSTACK and add some color
d::listcolor() {
    while read -r pos dir; do
        if [[ ${dir/\~/$HOME} = "$PWD" ]]; then
            printf "%-15b %s\\n" "$(_d::magenta "<$pos>")" "$dir"
        else
            printf "%-15b %s\\n" "$(_d::blue "$pos")"  "$dir"
        fi
    done < <(d::list)
}

# initialized the global assoc. array _d_cmds
_d::setup_cmd_list() {
    for k in "${_d_cmd_keys[@]}"; do
        case $k in
            list)
                _d_cmds[$k]="display \$DIRSTACK"
                ;;
            cd)
                _d_cmds[$k]="cd to th directory in \$DIRSTACK <tab complete>"
                ;;
            up)
                _d_cmds[$k]="go to a parent directory of \$PWD <tab complete>"
                ;;
            add)
                _d_cmds[$k]="add \$PWD to \$DIRSTACK"
                ;;
            addirs)
                _d_cmds[$k]="add directories in \$PWD to \$DIRSTACK"
                ;;
            del_byname)
                _d_cmds[$k]="delete directory from \$DIRSTACK by name <tab complete>"
                ;;
            del_byindex)
                _d_cmds[$k]="delete directory from \$DIRSTACK by index"
                ;;
            update)
                _d_cmds[$k]="read \$DIR_STORE and update \$DIRSTACK"
                ;;
            reset)
                _d_cmds[$k]="wipe \$DIRSTACK and \$DIR_STORE"
                ;;
        esac
    done
}

# completion function
_d::complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    case $COMP_CWORD in
        1)
            local i=0
            if [[ -n $cur ]]; then
                for k in "${!_d_cmds[@]}"; do
                    if [[ "$k" =~ ^$cur ]]; then
                        COMPREPLY[i++]=$k
                    fi
                done
            else
                for k in "${_d_cmd_keys[@]}"; do
                    printf -v _cmd_desc "%-15s%s" "$k" "${_d_cmds[$k]}"
                    printf -v "COMPREPLY[i++]" "%-*s" $COLUMNS "$_cmd_desc"
                done
            fi
            ;;
        2)
            case "$prev" in
                cd|del_byname)
                    local i=0
                    while read -r _dir; do
                        if [[ $_dir =~ ^${cur//./\\.} ]]; then
                            printf -v "COMPREPLY[i++]" "%-*s" $COLUMNS "$_dir"
                        fi
                    done < <(_d::uniq_dir_parts)
                    ;;
                up)
                    local i=0
                    while read -r _subdir; do
                        if [[ $_subdir =~ ^$cur ]]; then
                            printf -v "COMPREPLY[i++]" "%s" "$_subdir"
                        fi
                    done < <(_d::split_into_subdirs "${PWD%/*}")
                    ;;
            esac
            ;;
        *)
            return 0
            ;;
    esac
}

# main functions to easy navigate $DIRSTACK
d::main() {
    local _cmd=$1; shift
    case "$_cmd" in
        list)
            d::listcolor
            return 0
            ;;
        add)
            d::add; d::update; return 0
            ;;
        addirs)
            d::addmany; d::update;  return 0
            ;;
        cd)
            d::cd "$(_d::get_pos_in_stack "$*")"
            ;;
        up)
            d::up "$*"
            ;;
        del_byname)
            d::delete "$(_d::get_pos_in_stack "$*")"
            ;;
        del_byindex)
            d::delete "$*"
            ;;
        reset)
            d::clear; return 0
            ;;
        update)
            d::update
            ;;
    *)
        echo -e "$(_d::red "Unknown option $1")"
        ;;
    esac
}

# setup the environment
unset _d_cmd_keys
_d_cmd_keys=(list cd up add addirs del_byname del_byindex update reset)
unset _d_cmds
declare -A _d_cmds
_d::setup_cmd_list
eval "alias $LEADER=d::main"
if (( $(_d::bash_ver_toint "$BASH_VERSION") >= 4418 )); then
    complete -o nosort -F _d::complete "$LEADER"
else
    complete -F _d::complete "$LEADER"
fi
d::update
