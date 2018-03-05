# DISCOVERONLY=1
# DEBUG=1
STOP=1

source assert.sh
source d.sh

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

assert_end "tests"
