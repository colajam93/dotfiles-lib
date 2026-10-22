_dfl_red=$(tput setaf 1 2> /dev/null)
_dfl_yellow=$(tput setaf 3 2> /dev/null)
_dfl_blue=$(tput setaf 4 2> /dev/null)
_dfl_reset=$(tput sgr0 2> /dev/null)

_dfl_overwrite_file() {
    local destfile_new=$1
    local destfile_old=$2
    mv -- "$destfile_new" "$destfile_old"
    dfl_print_information "mv $destfile_new $destfile_old"
}

_dfl_is_quiet() {
    [[ "${_dfl_quiet:-false}" == "true" ]]
    return $?
}

dfl_print_error() {
    if _dfl_is_quiet; then
        return 0
    fi
    echo "${_dfl_red}error:${_dfl_reset} $1"
}

dfl_print_warning() {
    if _dfl_is_quiet; then
        return 0
    fi
    echo "${_dfl_yellow}warning:${_dfl_reset} $1"
}

dfl_print_information() {
    if _dfl_is_quiet; then
        return 0
    fi
    echo "${_dfl_blue}information:${_dfl_reset} $1"
}

dfl_safe_install() {
    # source file
    if [[ -e $1 ]]; then
        local srcfile
        srcfile=$(readlink -f -- "$1") || return 1
    else
        echo "$1: No such file or directory"
        return 1
    fi

    # destination file
    local destfile
    if [[ -d $2 ]]; then
        local filename
        filename=$(basename -- "$srcfile") || return 1
        destfile=$(readlink -f -- "$2/$filename") || return 1
    else
        destfile=$(readlink -f -- "$2") || return 1
    fi

    # if argc == 3, use 3rd argument as permission mode which pass to install -m
    local permission='644'
    if [[ $# -eq 3 ]]; then
        permission=$3
    fi

    # overwrite check
    # same file
    if cmp -s -- "$srcfile" "$destfile"; then
        dfl_print_information "skipped ${destfile}"
        return 0
    # destfile already exists
    elif [[ -e $destfile ]]; then
        local destfile_old=$destfile
        local destfile_new=$destfile.dotnew
        destfile=$destfile_new
        dfl_print_warning "${destfile_old} saved as ${destfile}"
    fi

    install -m "$permission" -- "$srcfile" "$destfile" || return 1
    dfl_print_information "installed in ${destfile}"

    if [[ $destfile_new != "" ]]; then
        if [[ "${_dfl_force:-false}" == "true" ]]; then
            _dfl_overwrite_file "$destfile_new" "$destfile_old"
        else
            diff --color=auto -u -- "$destfile_old" "$destfile_new"
            echo "overwrite $destfile_old by new file? [y/N]"
            local input
            read -r input
            if [[ $input == "y" ]]; then
                _dfl_overwrite_file "$destfile_new" "$destfile_old"
            fi
        fi
    fi
}

dfl_dotfile_install() {
    if [[ $# -ne 2 ]]; then
        return 1
    fi

    # destination file
    local destfile
    # src is not dotfile and dest is directory
    if ! [[ $1 == .* ]] && [[ -d $2 ]]; then
        local filename
        filename=$(basename -- "$1") || return 1
        destfile=$(readlink -f -- "$2/.$filename") || return 1
    # do nothing
    else
        destfile=$2
    fi

    dfl_safe_install "$1" "$destfile"
}

dfl_install_all() {
    local target_dir=$1
    shift
    [[ -d $target_dir ]] || return 1
    local patterns=('install.sh' '.*.swp' "$@")
    local i srcfile pattern regex pattern_status
    for pattern in "${patterns[@]}"; do
        regex="${pattern}$"
        if [[ '' =~ $regex ]]; then
            continue
        else
            # Intentionally inspect =~ status 2 (invalid regex), not just 0/1.
            # shellcheck disable=SC2319
            pattern_status=$?
            [[ $pattern_status -ne 2 ]] || return 1
        fi
    done
    while IFS= read -r -d '' i; do
        for pattern in "${patterns[@]}"; do
            # Preserve the existing ERE matching against the source path.
            regex="${pattern}$"
            if [[ $i =~ $regex ]]; then
                continue 2
            fi
        done
        srcfile=$(readlink -f -- "$i") || return 1
        dfl_dotfile_install "$srcfile" "$HOME"
    done < <(find "$target_dir" -maxdepth 1 -type f -print0)
}

dfl_platform_name() {
    local n
    n=$(uname -s) || return 1
    if [[ $n == "Linux" ]]; then
        echo "linux"
    elif [[ $n == "Darwin" ]]; then
        echo "mac"
    else
        echo "$n"
    fi
}

dfl_installed() {
    type "$1" &> /dev/null
    return $?
}
