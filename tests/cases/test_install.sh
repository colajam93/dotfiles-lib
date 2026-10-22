#!/usr/bin/env bash

oneTimeSetUp() {
    export LIBSS_TEST_CONTENT="foo"
    export LIBSS_TEST_INPUT="input"
}

oneTimeTearDown() {
    unset LIBSS_TEST_CONTENT
    unset LIBSS_TEST_INPUT
}

setUp() {
    cd $SHUNIT_TMPDIR
    find . -name . -o -prune -exec rm -rf -- {} +
    echo $LIBSS_TEST_CONTENT > $LIBSS_TEST_INPUT
}

test_overwrite_file_only_move() {
    # same as 'mv input moved' and print some information
    local result=$(_overwrite_file $LIBSS_TEST_INPUT moved)

    assertTrue "[[ -f moved ]]"
    assertFalse "[[ -f $LIBSS_TEST_INPUT ]]"
    local content=$(<moved)
    assertEquals "$LIBSS_TEST_CONTENT" $content

    assertEquals "$(tput setaf 4)information:$(tput sgr0) mv $LIBSS_TEST_INPUT moved" "$result"
}

test_overwrite_file_overwrite() {
    touch moved
    # overwrite
    local result=$(_overwrite_file $LIBSS_TEST_INPUT moved)

    assertTrue "[[ -f moved ]]"
    assertFalse "[[ -f $LIBSS_TEST_INPUT ]]"

    local content=$(<moved)
    assertEquals "$LIBSS_TEST_CONTENT" $content

    assertEquals "$(tput setaf 4)information:$(tput sgr0) mv $LIBSS_TEST_INPUT moved" "$result"
}

test_safe_install_source_missing() {
    local code
    local result
    result=$(safe_install missing bar)
    code=$?
    assertEquals 1 "$code"
    assertEquals "missing: No such file or directory" "$result"
}

test_safe_install_destination_file() {
    # output include path resolve so test is omitted
    safe_install $LIBSS_TEST_INPUT moved &> /dev/null
    assertTrue "[[ -f moved ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    local content=$(<moved)
    assertEquals "$LIBSS_TEST_CONTENT" $content
}

test_safe_install_destination_directory() {
    mkdir d
    # output include path resolve so test is omitted
    safe_install $LIBSS_TEST_INPUT d &> /dev/null
    assertTrue "[[ -f d/$LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    local content="$(<d/$LIBSS_TEST_INPUT)"
    assertEquals "$LIBSS_TEST_CONTENT" $content
}

test_safe_install_source_symlink() {
    mkdir source destination
    ln -s "../$LIBSS_TEST_INPUT" source/link

    safe_install source/link destination &> /dev/null

    assertTrue "[[ -L source/link ]]"
    assertTrue "[[ -f destination/$LIBSS_TEST_INPUT ]]"
    assertFalse "[[ -e destination/link ]]"
    assertEquals "$LIBSS_TEST_CONTENT" "$(cat "destination/$LIBSS_TEST_INPUT")"
}

test_safe_install_destination_symlink() {
    mkdir destination
    echo old > destination/target
    ln -s target destination/link

    _dotfiles_force=true safe_install "$LIBSS_TEST_INPUT" destination/link &> /dev/null

    assertTrue "[[ -L destination/link ]]"
    assertEquals "target" "$(readlink destination/link)"
    assertEquals "$LIBSS_TEST_CONTENT" "$(cat destination/target)"
    assertFalse "[[ -e destination/target.dotnew ]]"
}

test_safe_install_destination_dangling_symlink() {
    mkdir destination
    ln -s target destination/link

    safe_install "$LIBSS_TEST_INPUT" destination/link &> /dev/null

    assertTrue "[[ -L destination/link ]]"
    assertEquals "target" "$(readlink destination/link)"
    assertEquals "$LIBSS_TEST_CONTENT" "$(cat destination/target)"
}

test_safe_install_destination_permission() {
    # output include path resolve so test is omitted
    safe_install $LIBSS_TEST_INPUT moved 456 &> /dev/null
    assertTrue "[[ -f moved ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    local content="$(<moved)"
    assertEquals "$LIBSS_TEST_CONTENT" $content
    assertEquals "456" "$(stat -c %a moved)"
}

test_safe_install_destination_permission_default() {
    # output include path resolve so test is omitted
    safe_install $LIBSS_TEST_INPUT moved &> /dev/null
    assertTrue "[[ -f moved ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    local content="$(<moved)"
    assertEquals "$LIBSS_TEST_CONTENT" $content
    assertEquals "644" "$(stat -c %a moved)"
}


test_safe_install_skip() {
    echo $LIBSS_TEST_CONTENT > moved

    safe_install $LIBSS_TEST_INPUT moved &> /dev/null
    assertTrue "[[ -f moved ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    local content="$(<moved)"
    assertEquals "$LIBSS_TEST_CONTENT" $content
}

libss_test_safe_install_not_overwrite() {
    echo "${LIBSS_TEST_CONTENT}_bar" > moved

    echo $1 | safe_install $LIBSS_TEST_INPUT moved &> /dev/null
    assertTrue "[[ -f moved ]]"
    assertTrue "[[ -f moved.dotnew ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"

    local content_old="$(<moved)"
    assertEquals $content_old "${LIBSS_TEST_CONTENT}_bar"
    local content_new="$(<moved.dotnew)"
    assertEquals $content_new "$LIBSS_TEST_CONTENT"
}

test_safe_install_not_overwrite1() {
    libss_test_safe_install_not_overwrite
}

test_safe_install_not_overwrite2() {
    libss_test_safe_install_not_overwrite "\n"
}

test_safe_install_not_overwrite3() {
    libss_test_safe_install_not_overwrite "n"
}

test_safe_install_not_overwrite4() {
    libss_test_safe_install_not_overwrite "N"
}

test_safe_install_not_overwrite5() {
    libss_test_safe_install_not_overwrite "m"
}

libss_test_safe_install_overwrite_prepare() {
    echo "${LIBSS_TEST_CONTENT}_bar" > moved
}

libss_test_safe_install_overwrite_check() {
    assertTrue "[[ -f moved ]]"
    assertFalse "[[ -f moved.dotnew ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    local content="$(<moved)"
    assertEquals $content "$LIBSS_TEST_CONTENT"
}

test_safe_install_overwrite() {
    libss_test_safe_install_overwrite_prepare
    echo y | safe_install $LIBSS_TEST_INPUT moved &> /dev/null
    libss_test_safe_install_overwrite_check
}

test_safe_install_overwrite_force() {
    export _dotfiles_force=true
    libss_test_safe_install_overwrite_prepare
    safe_install $LIBSS_TEST_INPUT moved &> /dev/null
    libss_test_safe_install_overwrite_check
    unset _dotfiles_force
}

test_dotfile_install_missing_argument() {
    local code
    dotfile_install
    code=$?
    assertTrue "[[ $code -eq 1 ]]"
    dotfile_install foo
    code=$?
    assertTrue "[[ $code -eq 1 ]]"
    dotfile_install foo bar baz
    code=$?
    assertTrue "[[ $code -eq 1 ]]"
}

test_dotfile_install_normal_to_directory() {
    dotfile_install $LIBSS_TEST_INPUT $SHUNIT_TMPDIR &> /dev/null
    assertTrue "[[ -f .$LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    local content="$(<.$LIBSS_TEST_INPUT)"
    assertEquals $content "$LIBSS_TEST_CONTENT"
}

test_dotfile_install_normal_to_file() {
    dotfile_install $LIBSS_TEST_INPUT moved &> /dev/null
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f moved ]]"
    local content="$(<moved)"
    assertEquals $content "$LIBSS_TEST_CONTENT"
}

test_dotfile_install_dotfile_to_directory() {
    mkdir d
    echo $LIBSS_TEST_CONTENT > .dot
    dotfile_install .dot d &> /dev/null
    assertTrue "[[ -f .dot ]]"
    assertTrue "[[ -f d/.dot ]]"
    local content="$(<d/.dot)"
    assertEquals $content "$LIBSS_TEST_CONTENT"
}

test_dotfile_install_dotfile_to_file() {
    echo $LIBSS_TEST_CONTENT > .dot
    dotfile_install .dot moved &> /dev/null
    assertTrue "[[ -f .dot ]]"
    assertTrue "[[ -f moved ]]"
    local content="$(<moved)"
    assertEquals $content "$LIBSS_TEST_CONTENT"
}

test_install_all_one() {
    mkdir d
    tmp_home=$HOME
    export HOME="$SHUNIT_TMPDIR/d"
    install_all $SHUNIT_TMPDIR &> /dev/null
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f $SHUNIT_TMPDIR/d/.$LIBSS_TEST_INPUT ]]"
    local content="$(<$SHUNIT_TMPDIR/d/.$LIBSS_TEST_INPUT)"
    assertEquals $content "$LIBSS_TEST_CONTENT"
    export HOME=$tmp_home
}

test_install_all_some() {
    echo "${LIBSS_TEST_CONTENT}_a" > a
    echo "${LIBSS_TEST_CONTENT}_b" > b
    mkdir d
    tmp_home=$HOME
    export HOME="$SHUNIT_TMPDIR/d"
    install_all $SHUNIT_TMPDIR &> /dev/null
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f a ]]"
    assertTrue "[[ -f b ]]"
    assertTrue "[[ -f $SHUNIT_TMPDIR/d/.$LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f $SHUNIT_TMPDIR/d/.a ]]"
    assertTrue "[[ -f $SHUNIT_TMPDIR/d/.b ]]"
    local content="$(<$SHUNIT_TMPDIR/d/.$LIBSS_TEST_INPUT)"
    assertEquals $content "$LIBSS_TEST_CONTENT"
    content="$(<$SHUNIT_TMPDIR/d/.a)"
    assertEquals $content "${LIBSS_TEST_CONTENT}_a"
    content="$(<$SHUNIT_TMPDIR/d/.b)"
    assertEquals $content "${LIBSS_TEST_CONTENT}_b"
    export HOME=$tmp_home
}

test_install_all_exclude() {
    echo "${LIBSS_TEST_CONTENT}_a" > a
    echo "${LIBSS_TEST_CONTENT}_b" > b
    touch 'install.sh'
    touch '.foo.swp'
    mkdir d
    tmp_home=$HOME
    export HOME="$SHUNIT_TMPDIR/d"
    install_all $SHUNIT_TMPDIR a &> /dev/null
    assertTrue "[[ -f $LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f a ]]"
    assertTrue "[[ -f b ]]"
    assertTrue "[[ -f install.sh ]]"
    assertTrue "[[ -f .foo.swp ]]"
    assertTrue "[[ -f $SHUNIT_TMPDIR/d/.$LIBSS_TEST_INPUT ]]"
    assertTrue "[[ -f $SHUNIT_TMPDIR/d/.b ]]"
    assertFalse "[[ -f $SHUNIT_TMPDIR/d/.a ]]"
    assertFalse "[[ -f $SHUNIT_TMPDIR/d/.install.sh ]]"
    assertFalse "[[ -f $SHUNIT_TMPDIR/d/.foo.swp ]]"
    export HOME=$tmp_home
}

if [[ -n "$ZSH_VERSION" ]]; then  # zsh
    SHUNIT_PARENT=$0
    setopt shwordsplit
    script_dir="$( cd "$( dirname "${(%):-%N}" )" && pwd )"
else  # bash
    script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

if ! [[ -f "${SHUNIT2:-/usr/share/shunit2/shunit2}" ]]; then
    echo "fatal: shunit2 not found"
    exit 1
fi

source "$script_dir/../../dotfiles-lib.sh"
source "${SHUNIT2:-/usr/share/shunit2/shunit2}"
