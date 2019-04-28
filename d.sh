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
    local _exp_params=()
    local _params _values
    read -ra _params <<<"$1"
    for i in "${_params[@]}"; do
        if [[ $i =~ ^([0-9]+)-([0-9]+)$ ]]; then
            _values=$(eval "echo {${BASH_REMATCH[1]}..${BASH_REMATCH[2]}}")
            _exp_params+=("$_values")
        else
            [[ $i =~ ^[0-9]+$ ]] && _exp_params+=("$i")
        fi
    done
    _d::sort "${_exp_params[@]}"
}

# rm nth element from $DIRSTACK
_d::delete() {
    [[ "$*" = "" ]] && { _d::red "to delete, select a directory"; return 1; }
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
    local _path="$1"
    if [[ $_path =~ ^\. ]]; then
        _path="${_path/./$PWD}"
    elif [[ ! $_path =~ ^/|^\. ]]; then
        _path="$PWD/$_path"
    fi
    echo "$_path"
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

_d::get_dir_from_stack() {
    local -n _dir_ref=$1
    local _pos=$2
    local _err_regexp=".+$_pos:(.+)(out.+range)$"
    _dir_ref=$(dirs -l "+$_pos" 2>&1)
    if [[ $_dir_ref =~ $_err_regexp ]]; then
        _d::red "ERROR: ${BASH_REMATCH[1]} '$_dir_ref' ${BASH_REMATCH[2]}"
        return 1
    fi
    return 0
}

# convert $BASH_VERSION to int
_d::bash_ver_toint() { local _ver="${BASH_VERSION::3}"; echo "${_ver//[.]/}"; }

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
    local _dir_tilde_expanded _pos="$1"
    [[ $_pos = "" ]] && { cd "$HOME"; return 0; }
    if _d::get_dir_from_stack _dir_tilde_expanded "$_pos"; then
        if [[ -d $_dir_tilde_expanded ]]; then
            cd "$_dir_tilde_expanded"
        else
            _d::red "ERROR: directory '$_dir_tilde_expanded' does not exist\n"
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
        awk 'NR > 1' <(dirs -l -p) <(echo "$PWD") | sort | uniq > "$DIR_STORE"
    fi
}

# add all directories available in $PWD
d::addmany() { awk 'NR > 1' <(dirs -l -p) <(find "$PWD" -maxdepth 1 -mindepth 1 -type d -name "[^.]*") \
               | sort | uniq >"$DIR_STORE"; }

# update $DIRSTACK from $DIR_STORE
d::update() { _d::populate "$PWD"; }

# list $DIRSTACK
d::list() { dirs -v -p | awk 'NR > 1'; }

d::up() { cd "$(_d::trim_path "$PWD" "$*")"; }

# cp/mv $1 to directory at pos $2 in $DIRSTACK
d::run_op() {
    local _fso _dir_tilde_expanded _opts="-v" _op=$1 _src=$2 _pos=$3
    if _d::get_dir_from_stack _dir_tilde_expanded "$_pos"; then
        # next two steps are there to make globbing of <partial filename>\ * work
        # if $_src contains a * remove it
        _src=$([[ $_src =~ ([^*]+) ]] && echo "${BASH_REMATCH[0]}" || echo "${_src}")
        # replace all occurences of "\ " with " "
        for _fso in "${_src//\\ / }"*; do
            [[ $_op == cp ]] && [[ -f $_fso ]] && "$_op" "${_opts}p" "$_fso" "$_dir_tilde_expanded"
            [[ $_op == cp ]] && [[ -d $_fso ]] && "$_op" "${_opts}pr" "$_fso" "$_dir_tilde_expanded"
            [[ $_op == mv ]] && "$_op" "${_opts}" "$_fso" "$_dir_tilde_expanded"
        done
    fi
}

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
                _d_cmds[$k]="cd to directory in \$DIRSTACK <tab complete>"
                ;;
            copy)
                _d_cmds[$k]="copy from \$PWD <tab complete> to directory in \$DIRSTACK <tab complete>"
                ;;
            move)
                _d_cmds[$k]="move from \$PWD <tab complete> to directory in \$DIRSTACK <tab complete>"
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
    if [[ $COMP_CWORD -eq 1 ]]; then
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
    elif [[ $COMP_CWORD -gt 1 ]]; then
        if [[ ${COMP_WORDS[1]} =~ cd|del_byname ]]; then
            while read -r _dir; do
                if [[ $_dir =~ ^${cur//./\\.} ]]; then
                    COMPREPLY+=("$_dir")
                fi
            done < <(_d::uniq_dir_parts)
        elif [[ ${COMP_WORDS[1]} == up ]]; then
            while read -r _subdir; do
                if [[ $_subdir =~ ^$cur ]]; then
                    COMPREPLY+=("$_subdir")
                fi
            done < <(_d::split_into_subdirs "${PWD%/*}")
        elif [[ ${COMP_WORDS[1]} =~ copy|move ]]; then
            if (( COMP_CWORD == 2 )); then
                if [[ -z ${COMP_WORDS[COMP_CWORD]} ]]; then
                    mapfile -t COMPREPLY < <(ls -p1)
                else
                    local fso
                    printf -v cur "%q" "${COMP_WORDS[COMP_CWORD]}"
                    [[ $cur =~ .+\* ]] && { COMPREPLY+=("$cur"); return 0; }
                    while read -r fso; do
                        if [[ $(printf "%q" "$fso") =~ ^$cur ]]; then
                            COMPREPLY+=("$(printf "%q" "$fso")")
                        fi
                    done < <(ls -p1)
                fi
            elif (( COMP_CWORD == 3 )); then
                while read -r _dir; do
                    if [[ $_dir =~ ^${cur//./\\.} ]]; then
                        COMPREPLY+=("$_dir")
                    fi
                done < <(_d::uniq_dir_parts)
            fi
        fi
    fi
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
        copy)
            d::run_op 'cp' "$1" "$(_d::get_pos_in_stack "$2")"
            ;;
        move)
            d::run_op 'mv' "$1" "$(_d::get_pos_in_stack "$2")"
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
        _d::red "Unknown option $1"
        ;;
    esac
}

# setup the environment
unset _d_cmd_keys
_d_cmd_keys=(list cd copy move up add addirs del_byname del_byindex update reset)
unset _d_cmds
declare -A _d_cmds
_d::setup_cmd_list
eval "alias $LEADER=d::main"
if (( $(_d::bash_ver_toint "$BASH_VERSION") >= 44 )); then
    complete -o nosort -F _d::complete "$LEADER"
else
    complete -F _d::complete "$LEADER"
fi
d::update
