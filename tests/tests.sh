#!/usr/bin/env bash
source ./assert.sh
source ../d.sh

# DISCOVERONLY=1
DEBUG=1
STOP=1

set_up_general() {
    TMPDIR=$(mktemp -d)
    DIR_STORE_BAK=$DIR_STORE
    DIR_STORE=${TMPDIR}/.dir_store
    d::clear
    mkdir "${TMPDIR}"/{dir1,dir2,"dir 3",dir4}
    for d in "${TMPDIR}"/{dir1,dir2,"dir 3",dir4}; do
        pushd -n "$d" >/dev/null
    done
}

concat() {
    local _function=$1; shift
    local _delim=$1; shift
    local _concat=
    while read -r token; do
       _concat="$_concat$_delim$token"
    done < <($_function "$@")
    echo "$_concat"
}

tear_down() {
    rm -r "$TMPDIR"
    DIR_STORE="$DIR_STORE_BAK"
}

set_up_add() {
    d::clear
    cd "$TMPDIR"
    mkdir test_add
    cd - >/dev/null
    echo "${TMPDIR}/test_add"
}

set_up_addmany() {
    d::clear
    cd "$TMPDIR"
    mkdir -p test_addmany/{dir1,dir2}
    cd - >/dev/null
    echo "${TMPDIR}/test_addmany"
}

set_up_populate() {
    TMPDIR=$(mktemp -d)
    DIR_STORE_BAK=$DIR_STORE
    DIR_STORE=${TMPDIR}/.dir_store
    d::clear
    mkdir "${TMPDIR}"/{dir1,dir2}
}

print_info() {
    (( DEBUG )) && echo -e "$*"
}

c_randdir_home() {
    local rand_fname=
    rand_fname=$(mktemp)
    rm "$rand_fname"
    local rand_dir="${HOME}/${rand_fname##*/}"
    mkdir "$rand_dir"
    echo "$rand_dir"
}

print_info "testing _d::reverse_path"
assert "concat _d::reverse_path / /dir1/dir2/dir3" "/dir3/dir2/dir1"
assert "concat _d::reverse_path / \"/dir1/dir2 space/dir3\"" "/dir3/dir2 space/dir1"

print_info "\\ntesting _dd::is_unique"
_dirstack=(/dir1/tmp /dir1/dir2/tmp /dir1/dirX)
_result=$(_d::is_unique 0 tmp "${_dirstack[@]}")
assert "echo $_result" 1
_result=$(_d::is_unique 1 dir2/tmp "${_dirstack[@]}")
assert "echo $_result" 0
_result=$(_d::is_unique 2 dirX "${_dirstack[@]}")
assert "echo $_result" 0

print_info "\\ntesting _d::uniq_part_of_dir"
_dirstack=(dummy /dir2/tmp /dir0/dir2/tmp /tmp /dir1/dirX)
_result=$(concat _d::uniq_part_of_dir " " "${_dirstack[@]}")
assert "echo $_result" "dir2/tmp dir0/dir2/tmp tmp dirX"
_dirstack=(dummy /dir/dir1/xxx /dir/dir2/xxx /dir/dir3/xxx)
_result=$(concat _d::uniq_part_of_dir " " "${_dirstack[@]}")
assert "echo $_result" "dir1/xxx dir2/xxx dir3/xxx"
_dirstack=(dummy "/dir0/dir2 space/tmp" "/dir0/dir1 space/tmp" /tmp /dir1/dirX)
_result=$(concat _d::uniq_part_of_dir " " "${_dirstack[@]}")
assert "echo $_result" "dir2 space/tmp dir1 space/tmp tmp dirX"

print_info "\\ntesting _d::sort"
assert "_d::sort \"3 10 4 1 2 6 5 7 9 8\"" "10 9 8 7 6 5 4 3 2 1"

print_info "\\ntesting _d::expandparams"
assert "_d::expandparams \"3 2 1 7-9 6 4-5 10\"" "10 9 8 7 6 5 4 3 2 1"
assert "_d::expandparams \"3 2 1 9-7 6 4-5 10\"" "10 9 8 7 6 5 4 3 2 1"
assert "_d::expandparams \"3 2 a 1 9-7 6 4-5 b 10\"" "10 9 8 7 6 5 4 3 2 1"
assert "_d::expandparams \"1\"" "1"

print_info "\\ntesting _d::prependpwd"
assert "_d::prependpwd \"./test_dir\"" "$PWD/test_dir"
assert "_d::prependpwd \"/test_dir\"" "/test_dir"
assert "_d::prependpwd \"test_dir\"" "$PWD/test_dir"

print_info "\\ntesting _d::delete"
set_up_general
_d::delete 2-3
assert "dirs -l -v -p | awk 'NR > 1'" " 1  ${TMPDIR}/dir4\\n 2  ${TMPDIR}/dir1\\n"
_d::delete 1
assert "dirs -l -v -p | awk 'NR > 1'" " 1  ${TMPDIR}/dir1\\n"
_d::delete 2
assert "dirs -l -v -p | awk 'NR > 1'" " 1  ${TMPDIR}/dir1\\n"
_d::delete 1
assert "dirs -l -v -p | awk 'NR > 1'" ""
tear_down "$TMPDIR"

print_info "\\ntesting _d::get_pos_in_stack"
set_up_general
assert "_d::get_pos_in_stack \"dir4\"" "1"
assert "_d::get_pos_in_stack \"dir 3\"" "2"
tear_down "$TMPDIR"

print_info "\\ntesting d::add"
set_up_general
add_dir=$(set_up_add)
cd "$add_dir"
d::add
assert "grep $add_dir $DIR_STORE" "$add_dir"
cd - >/dev/null
tear_down "$TMPDIR"

print_info "\\ntesting d::addmany"
set_up_general
addmany_dir=$(set_up_addmany)
cd "$addmany_dir"
d::addmany
expected_num_lines=$(grep -c "$addmany_dir" "$DIR_STORE")
assert "echo ${expected_num_lines##* }" "2"
cd - >/dev/null
tear_down "$TMPDIR"

print_info "\\ntesting _d::populate"
set_up_populate
for d in "${TMPDIR}"/{dir1,dir2}; do
    echo "$d" >>"$DIR_STORE"
    _d::populate "$PWD"
    assert "echo $(d::list | tail -1 | awk '{print $2}')" "$d"
done
tear_down "$TMPDIR"

print_info "\\ntesting d::cd"
set_up_general
# cd from $TMPDIR to $HOME (d::cd with no argument
cd "$TMPDIR"
d::cd
assert "echo $PWD" "$HOME"

# create a tempdir in $HOME; add it to $DIRSTACK; cd to $HOME and back into it
tmpdir_in_home="$(c_randdir_home)"
cd "$tmpdir_in_home"
d::add; d::update
d::cd
d::cd 1
assert "echo $PWD" "$tmpdir_in_home"

# cd into $HOME rm tmpdir and try to cd back to into
d::cd
rmdir "$tmpdir_in_home"
assert_raises "d::cd 1 | grep \"does not exist\"" 0

# make sure that out of range error is handled properly
assert_raises "d::cd 10 | grep \"out of range\"" 0

tear_down "$TMPDIR"

# test splitting into subdirectories
print_info "\\ntesting _d::split_into_subdirs"
assert "_d::split_into_subdirs /dir0/dir1/dir2/dir3" "dir0\\ndir1\\ndir2\\ndir3\\n"

# test _d::trim_path
print_info "\\ntesting _d::trim_path"
assert "_d::trim_path /dir0/dir1/dir2/dir3 dir1" "/dir0/dir1"
assert "_d::trim_path /dir0/dir1/dir2/dir3 dir0" "/dir0"
assert "_d::trim_path /dir0/dir1/dir2/dir3 dirx" ""

assert_end "tests"
