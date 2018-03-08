DIR_STORE=${DIR_STORE:-"${HOME}/.dir_store"}
LEADER=${LEADER:-","}

# colors
readonly D_RESET_COL='\033[m'
readonly D_COLOR_BLUE='\033[0;34m'
readonly D_COLOR_RED='\033[0;31m'
readonly D_COLOR_MAGENTA='\033[0;35m'

_d::blue() { echo -en "$D_COLOR_BLUE$*$D_RESET_COL"; }
_d::red() { echo -en "$D_COLOR_RED$*$D_RESET_COL"; }
_d::magenta() { echo -en "$D_COLOR_MAGENTA$*$D_RESET_COL"; }

# reverses a given path
# $1=/dir1/dir2/dir3 ->  dir3 dir2 dir1
# $1=/dir1/space dir2/dir3 ->  dir3 space,dir2 dir1
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

# ckecks if $1 matches the end of path at pos $2 in ("$@")
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

# determines all unique parts of the path values contained in ("${@}")
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
    # replace all spaces with "," to avoid that
    # one dirstack element is treated as two
    echo "${_uniq_dirs[@]// /,}"
}

# get all unique parts of the pathes stored in $DIRSTACK
_d::uniq_dir_parts() { echo "$(_d::uniq_part_of_dir "${DIRSTACK[@]}")"; }

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
        # remove last entry from $DIRSTACK ($working_dir)
        eval "popd +$(( ${#DIRSTACK[@]} - 1 )) >/dev/null"
    fi
}

# sort numeric parameters in desc order
_d::sort() { local _s=$(echo "$*" | tr " " "\n" | sort -nr | tr "\n" " "); echo ${_s# }; }

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
    dirs -l -p | awk 'NR > 1' >$DIR_STORE
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

# returns position of dir_name in $DIRSTACK
_d::get_pos_in_stack() {
    local dir_name="$*"
    while read _pos _dir; do
        if [[ $_dir =~ /${dir_name}$ ]]; then
            echo $_pos
            break
        fi
    done < <(d::list)
}

# cd to the nth element in $DIRSTACK
d::cd() {
    (( ${#*} == 0 )) && { cd $HOME; return 0; }
    local err_msg=
    local err_regexp=".+$1:(.+)(out.+range)$"
    local dir_tilde_expanded=$(dirs -l +$1 2>&1)
    if [[ $dir_tilde_expanded =~ $err_regexp ]]; then
        err_msg="ERROR: ${BASH_REMATCH[1]} '$1' ${BASH_REMATCH[2]}"
        echo -e $(_d::red $err_msg)
    else
        if [[ -d $dir_tilde_expanded ]]; then
            cd "$dir_tilde_expanded"
        else
            err_msg="ERROR: directory '$dir_tilde_expanded' does not exist"
            echo -e $(_d::red $err_msg)
        fi
    fi
}

# clears $DIRSTACK and wipes $DIR_STORE
d::clear() { dirs -c; cat /dev/null >$DIR_STORE; }

# rm nth element from $DIRSTACK and write to $DIR_STORE
d::delete() { _d::delete $*; d::update; }

# add current directory to $DIRSTACK
d::add() {
    if [[ "$PWD" != "$HOME" ]]; then
        awk 'NR > 1' <(dirs -l -p) <(echo $PWD) | sort | uniq >$DIR_STORE
    fi
}

# add all directories available in $PWD
d::addmany() { find . -type d -depth 1 | _d::addmany; }

# update $DIRSTACK from $DIR_STORE
d::update() { _d::populate "$PWD"; }

# list $DIRSTACK
d::list() { dirs -v -p | awk 'NR > 1'; }

# list $DIRSTACK and add some color
d::listcolor() {
    while read pos dir; do
        if [[ ${dir/\~/$HOME} = $PWD ]]; then
            echo -e " $(_d::magenta "<$pos>") $dir"
        else
            echo -e "  $(_d::blue $pos)  $dir"
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
                _d_cmds[$k]="cd to directory in \$DIRSTACK"
                ;;
            add)
                _d_cmds[$k]="add \$PWD to \$DIRSTACK"
                ;;
            addirs)
                _d_cmds[$k]="add directories in \$PWD to \$DIRSTACK"
                ;;
            delete)
                _d_cmds[$k]="delete directory from \$DIRSTACK"
                ;;
            update)
                _d_cmds[$k]="read \$DIR_STORE and update \$DIRSTACK"
                ;;
            clear)
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
                    printf -v _cmd_desc "%-15s%s" $k "${_d_cmds[$k]}"
                    printf -v 'COMPREPLY[i++]' '%-*s' $COLUMNS "$_cmd_desc"
                done
            fi
            ;;
        2)
            case "$prev" in
                cd|delete)
                    local _dirs=($(_d::uniq_dir_parts))
                    for i in ${!_dirs[@]}; do
                        if [[ ${_dirs[$i]} =~ ^$cur ]]; then
                            printf -v 'COMPREPLY[$i]' '%-*s' $COLUMNS "${_dirs[$i]//,/ }"
                        fi
                    done
                    ;;
            esac
            ;;
        *)
            return 0
            ;;
    esac
}

# main functions to easy navigate $DIRSTACK
d() {
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
            d::cd $(_d::get_pos_in_stack $*)
            ;;
        delete)
            d::delete $(_d::get_pos_in_stack $*)
            ;;
        clear)
            d::clear; return 0
            ;;
        update)
            d::update
            ;;
    *)
        echo -e $(_d::red "Unknown option $1")
        ;;
    esac
}

# setup the environment
unset _d_cmd_keys
_d_cmd_keys=("list" "cd" "add" "addirs" "delete" "update" "clear")
unset _d_cmds
declare -A _d_cmds
_d::setup_cmd_list
complete -o nosort -F _d::complete d
d::update
