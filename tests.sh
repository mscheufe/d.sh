source assert.sh
source d.sh

# DISCOVERONLY=1
# DEBUG=1
STOP=1

set_up() {
    d::clear
    TMPDIR=$(mktemp -d)
    mkdir ${TMPDIR}/{dir1,dir2,"dir 3",dir4}
    for d in ${TMPDIR}/{dir1,dir2,"dir 3",dir4}; do
        pushd -n "$d" >/dev/null
    done
    DIR_STORE_BAK=$DIR_STORE
    DIR_STORE=${TMPDIR}/.dir_store
    # dirs -l -v -p | awk 'NR > 1'
}

tear_down() {
    rm -r $TMPDIR
    DIR_STORE=$DIR_STORE_BAK
}

echo "testing _d::reverse_path"
assert "_d::reverse_path /dir1/dir2/dir3" "dir3 dir2 dir1"
assert "_d::reverse_path \"/dir1/dir2 space/dir3\"" "dir3 dir2,space dir1"

echo "testing _dd:is_unique"
_dirstack=(/dir1/tmp /dir1/dir2/tmp /dir1/dirX)
_result=$(_d::is_unique 0 tmp "${_dirstack[@]}")
assert "echo $_result" 1
assert "echo $_result" 1
_result=$(_d::is_unique 1 dir2/tmp "${_dirstack[@]}")
assert "echo $_result" 0
_result=$(_d::is_unique 2 dirX "${_dirstack[@]}")
assert "echo $_result" 0

echo "testing _d::uniq_part_of_dir"
_dirstack=(dummy /dir2/tmp /dir0/dir2/tmp /tmp /dir1/dirX)
_result=$(_d::uniq_part_of_dir "${_dirstack[@]}")
assert "echo $_result" "dir2/tmp dir0/dir2/tmp tmp dirX"
_dirstack=(dummy /dir/dir1/xxx /dir/dir2/xxx /dir/dir3/xxx)
_result=$(_d::uniq_part_of_dir "${_dirstack[@]}")
assert "echo $_result" "dir1/xxx dir2/xxx dir3/xxx"
_dirstack=(dummy "/dir0/dir2 space/tmp" "/dir0/dir1 space/tmp" /tmp /dir1/dirX)
_result="$(_d::uniq_part_of_dir "${_dirstack[@]}")"
assert "echo $_result" "dir2,space/tmp dir1,space/tmp tmp dirX"

echo "testing _d::sort"
assert "_d::sort \"3 10 4 1 2 6 5 7 9 8\"" "10 9 8 7 6 5 4 3 2 1"

echo "testing _d::expandparams"
assert "_d::expandparams \"3 2 1 7-9 6 4-5 10\"" "10 9 8 7 6 5 4 3 2 1"

echo "testing _d::prependpwd"
assert "_d::prependpwd \"./test_dir\"" "$PWD/test_dir"
assert "_d::prependpwd \"/test_dir\"" "/test_dir"
assert "_d::prependpwd \"test_dir\"" "$PWD/test_dir"

echo "testing _d::delete"
set_up
_d::delete 2-3
assert "dirs -l -v -p | awk 'NR > 1'" " 1  ${TMPDIR}/dir4\n 2  ${TMPDIR}/dir1\n"
_d::delete 1
assert "dirs -l -v -p | awk 'NR > 1'" " 1  ${TMPDIR}/dir1\n"
_d::delete 2
assert "dirs -l -v -p | awk 'NR > 1'" " 1  ${TMPDIR}/dir1\n"
tear_down $TMPDIR



assert_end "tests"
