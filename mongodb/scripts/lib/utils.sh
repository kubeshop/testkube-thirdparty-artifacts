#!/bin/bash

# Library for logging functions

# Constants
RESET='\033[0m'
RED='\033[38;5;1m'
GREEN='\033[38;5;2m'
YELLOW='\033[38;5;3m'
MAGENTA='\033[38;5;5m'
CYAN='\033[38;5;6m'

# Functions

########################
# Print to STDERR
# Globals:
#   QUIET
# Arguments:
#   Message to print
# Returns:
#   None
#########################
stderr_print() {
    local quiet_mode="${QUIET:-false}"

    # Print message if quiet mode is disabled
    if ! is_boolean_yes "$quiet_mode"; then
        printf "%b\\n" "${*}" >&2
    fi
}

########################
# Log message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
log() {
    stderr_print "{ 'module': '${CYAN}${MODULE:-}'${RESET}, 'date': '${MAGENTA}$(date)'${RESET}, 'level': ${*} }"
}
########################
# Log an 'info' message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
info() {
    log "'${GREEN}INFO'${RESET}, 'message': '${*}'"
}
########################
# Log message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
warn() {
    log "'${YELLOW}WARN'${RESET}, 'message': '${*}'"
}
########################
# Log an 'error' message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
error() {
    log "'${RED}ERROR'${RESET}, 'message': '${*}'"
}
########################
# Log a 'debug' message
# Globals:
#   DEBUG
# Arguments:
#   None
# Returns:
#   None
#########################
debug() {
    # 'is_boolean_yes' is defined in libvalidations.sh, but depends on this file so we cannot source it
    local bool="${DEBUG:-false}"
    # comparison is performed without regard to the case of alphabetic characters
    if is_boolean_yes "$bool"; then
        log "'${MAGENTA}DEBUG'${RESET}, 'message': '${*}'"
    fi
}

########################
# Indent a string
# Arguments:
#   $1 - string
#   $2 - number of indentation characters (default: 4)
#   $3 - indentation character (default: " ")
# Returns:
#   None
#########################
indent() {
    local string="${1:-}"
    local num="${2:?missing num}"
    local char="${3:-" "}"
    # Build the indentation unit string
    local indent_unit=""
    for ((i = 0; i < num; i++)); do
        indent_unit="${indent_unit}${char}"
    done
    # shellcheck disable=SC2001
    # Complex regex, see https://github.com/koalaman/shellcheck/wiki/SC2001#exceptions
    echo "$string" | sed "s/^/${indent_unit}/"
}


# Functions

########################
# Check if the script is currently running as root
# Arguments:
#   $1 - user
#   $2 - group
# Returns:
#   Boolean
#########################
am_i_root() {
    if [[ "$(id -u)" = "0" ]]; then
        true
    else
        false
    fi
}

########################
# Execute command as a specific user and group (optional),
# replacing the current process image
# Arguments:
#   $1 - USER(:GROUP) to switch to
#   $2..$n - command to execute
# Returns:
#   Exit code of the specified command
#########################
exec_as_user() {
    run_chroot --replace-process "$@"
}

########################
# Run a command using chroot
# Arguments:
#   $1 - USER(:GROUP) to switch to
#   $2..$n - command to execute
# Flags:
#   -r | --replace-process - Replace the current process image (optional)
# Returns:
#   Exit code of the specified command
#########################
run_chroot() {
    local userspec
    local user
    local homedir
    local replace=false
    local -r cwd="$(pwd)"

    # Parse and validate flags
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -r | --replace-process)
                replace=true
                ;;
            --)
                shift
                break
                ;;
            -*)
                stderr_print "unrecognized flag $1"
                return 1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    # Parse and validate arguments
    if [[ "$#" -lt 2 ]]; then
        echo "expected at least 2 arguments"
        return 1
    else
        userspec=$1
        shift

        # userspec can optionally include the group, so we parse the user
        user=$(echo "$userspec" | cut -d':' -f1)
    fi

    if ! am_i_root; then
        error "Could not switch to '${userspec}': Operation not permitted"
        return 1
    fi

    # Get the HOME directory for the user to switch, as chroot does
    # not properly update this env and some scripts rely on it
    homedir=$(eval echo "~${user}")
    if [[ ! -d $homedir ]]; then
        homedir="${HOME:-/}"
    fi

    # Obtaining value for "$@" indirectly in order to properly support shell parameter expansion
    if [[ "$replace" = true ]]; then
        exec chroot --userspec="$userspec" / bash -c "cd ${cwd}; export HOME=${homedir}; exec \"\$@\"" -- "$@"
    else
        chroot --userspec="$userspec" / bash -c "cd ${cwd}; export HOME=${homedir}; exec \"\$@\"" -- "$@"
    fi
}

########################
# Retries a command a given number of times
# Arguments:
#   $1 - cmd (as a string)
#   $2 - max retries. Default: 12
#   $3 - sleep between retries (in seconds). Default: 5
# Returns:
#   Boolean
#########################
retry_while() {
    local cmd="${1:?cmd is missing}"
    local retries="${2:-12}"
    local sleep_time="${3:-5}"
    local return_value=1

    read -r -a command <<<"$cmd"
    for ((i = 1; i <= retries; i += 1)); do
        "${command[@]}" && return_value=0 && break
        sleep "$sleep_time"
    done
    return $return_value
}

#########################
# Redirects output to /dev/null if debug mode is disabled
# Globals:
#   DEBUG
# Arguments:
#   $@ - Command to execute
# Returns:
#   None
#########################
debug_execute() {
    if is_boolean_yes "${DEBUG:-false}"; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

########################
# Run command as a specific user and group (optional)
# Arguments:
#   $1 - USER(:GROUP) to switch to
#   $2..$n - command to execute
# Returns:
#   Exit code of the specified command
#########################
run_as_user() {
    run_chroot "$@"
}

########################
# Ensure a directory exists and, optionally, is owned by the given user
# Arguments:
#   $1 - directory
#   $2 - owner
# Returns:
#   None
##########################
ensure_dir_exists() {
    local dir="${1:?directory is missing}"
    local owner_user="${2:-}"
    local owner_group="${3:-}"

    [ -d "${dir}" ] || mkdir -p "${dir}"
    if [[ -n $owner_user ]]; then
        owned_by "$dir" "$owner_user" "$owner_group"
    fi
}

########################
# Configure permisions
# Globals:
#   None
# Arguments:
#   $1 - path array
#   $2 - user
#   $3 - group
#   $4 - mode for directories
#   $5 - mode for files
# Returns:
#   None
#########################
configure_permissions() {
    local -r path=${1:?path is required}
    local -r user=${2:?user is required}
    local -r group=${3:?group is required}
    local -r dir_mode=${4:-false}
    local -r file_mode=${5:-false}

    if [[ -e "$path" ]]; then
        if [[ -n $dir_mode ]] && [[ -n $file_mode ]]; then
            find -L "$path" -type d -exec chmod "$dir_mode" {} \;
        fi
        if [[ -n $file_mode ]]; then
            find -L "$path" -type f -exec chmod "$file_mode" {} \;
        fi
        chown -LR "$user":"$group" "$path"
    else
        warn "$path do not exist."
    fi
}

########################
# Configure permisions and ownership recursively
# Globals:
#   None
# Arguments:
#   $1 - paths (as a string).
# Flags:
#   -f|--file-mode - mode for directories.
#   -d|--dir-mode - mode for files.
#   -u|--user - user
#   -g|--group - group
# Returns:
#   None
#########################
configure_permissions_ownership() {
    local -r paths="${1:?paths is missing}"
    local dir_mode=""
    local file_mode=""
    local user=""
    local group=""

    # Validate arguments
    shift 1
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -f | --file-mode)
            shift
            file_mode="${1:?missing mode for files}"
            ;;
        -d | --dir-mode)
            shift
            dir_mode="${1:?missing mode for directories}"
            ;;
        -u | --user)
            shift
            user="${1:?missing user}"
            ;;
        -g | --group)
            shift
            group="${1:?missing group}"
            ;;
        *)
            echo "Invalid command line flag $1" >&2
            return 1
            ;;
        esac
        shift
    done

    read -r -a filepaths <<<"$paths"
    for p in "${filepaths[@]}"; do
        if [[ -e "$p" ]]; then
            find -L "$p" -printf ""
            if [[ -n $dir_mode ]]; then
                find -L "$p" -type d ! -perm "$dir_mode" -print0 | xargs -r -0 chmod "$dir_mode"
            fi
            if [[ -n $file_mode ]]; then
                find -L "$p" -type f ! -perm "$file_mode" -print0 | xargs -r -0 chmod "$file_mode"
            fi
            if [[ -n $user ]] && [[ -n $group ]]; then
                find -L "$p" -print0 | xargs -r -0 chown "${user}:${group}"
            elif [[ -n $user ]] && [[ -z $group ]]; then
                find -L "$p" -print0 | xargs -r -0 chown "${user}"
            elif [[ -z $user ]] && [[ -n $group ]]; then
                find -L "$p" -print0 | xargs -r -0 chgrp "${group}"
            fi
        else
            stderr_print "$p does not exist"
        fi
    done
}

########################
# Ensure a file/directory is owned (user and group) but the given user
# Arguments:
#   $1 - filepath
#   $2 - owner
# Returns:
#   None
#########################
owned_by() {
    local path="${1:?path is missing}"
    local owner="${2:?owner is missing}"
    local group="${3:-}"

    if [[ -n $group ]]; then
        chown "$owner":"$group" "$path"
    else
        chown "$owner":"$owner" "$path"
    fi
}

########################
# Check if an user exists in the system
# Arguments:
#   $1 - user
# Returns:
#   Boolean
#########################
user_exists() {
    local user="${1:?user is missing}"
    id "$user" >/dev/null 2>&1
}

########################
# Check if a group exists in the system
# Arguments:
#   $1 - group
# Returns:
#   Boolean
#########################
group_exists() {
    local group="${1:?group is missing}"
    getent group "$group" >/dev/null 2>&1
}

########################
# Create a group in the system if it does not exist already
# Arguments:
#   $1 - group
# Flags:
#   -i|--gid - the ID for the new group
#   -s|--system - Whether to create new user as system user (uid <= 999)
# Returns:
#   None
#########################
ensure_group_exists() {
    local group="${1:?group is missing}"
    local gid=""
    local is_system_user=false

    # Validate arguments
    shift 1
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -i | --gid)
            shift
            gid="${1:?missing gid}"
            ;;
        -s | --system)
            is_system_user=true
            ;;
        *)
            echo "Invalid command line flag $1" >&2
            return 1
            ;;
        esac
        shift
    done

    if ! group_exists "$group"; then
        local -a args=("$group")
        if [[ -n "$gid" ]]; then
            if group_exists "$gid"; then
                error "The GID $gid is already in use." >&2
                return 1
            fi
            args+=("--gid" "$gid")
        fi
        $is_system_user && args+=("--system")
        groupadd "${args[@]}" >/dev/null 2>&1
    fi
}

########################
# Create an user in the system if it does not exist already
# Arguments:
#   $1 - user
# Flags:
#   -i|--uid - the ID for the new user
#   -g|--group - the group the new user should belong to
#   -a|--append-groups - comma-separated list of supplemental groups to append to the new user
#   -h|--home - the home directory for the new user
#   -s|--system - whether to create new user as system user (uid <= 999)
# Returns:
#   None
#########################
ensure_user_exists() {
    local user="${1:?user is missing}"
    local uid=""
    local group=""
    local append_groups=""
    local home=""
    local is_system_user=false

    # Validate arguments
    shift 1
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -i | --uid)
            shift
            uid="${1:?missing uid}"
            ;;
        -g | --group)
            shift
            group="${1:?missing group}"
            ;;
        -a | --append-groups)
            shift
            append_groups="${1:?missing append_groups}"
            ;;
        -h | --home)
            shift
            home="${1:?missing home directory}"
            ;;
        -s | --system)
            is_system_user=true
            ;;
        *)
            echo "Invalid command line flag $1" >&2
            return 1
            ;;
        esac
        shift
    done

    if ! user_exists "$user"; then
        local -a user_args=("-N" "$user")
        if [[ -n "$uid" ]]; then
            if user_exists "$uid"; then
                error "The UID $uid is already in use."
                return 1
            fi
            user_args+=("--uid" "$uid")
        else
            $is_system_user && user_args+=("--system")
        fi
        useradd "${user_args[@]}" >/dev/null 2>&1
    fi

    if [[ -n "$group" ]]; then
        local -a group_args=("$group")
        $is_system_user && group_args+=("--system")
        ensure_group_exists "${group_args[@]}"
        usermod -g "$group" "$user" >/dev/null 2>&1
    fi

    if [[ -n "$append_groups" ]]; then
        local -a groups
        read -ra groups <<<"$(tr ',;' ' ' <<<"$append_groups")"
        for group in "${groups[@]}"; do
            ensure_group_exists "$group"
            usermod -aG "$group" "$user" >/dev/null 2>&1
        done
    fi

    if [[ -n "$home" ]]; then
        mkdir -p "$home"
        usermod -d "$home" "$user" >/dev/null 2>&1
        configure_permissions_ownership "$home" -d "775" -f "664" -u "$user" -g "$group"
    fi
}

########################
# Check if the provided argument is a boolean or is the string 'yes/true'
# Arguments:
#   $1 - Value to check
# Returns:
#   Boolean
#########################
is_boolean_yes() {
    local -r bool="${1:-}"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    if [[ "$bool" = 1 || "$bool" =~ ^(yes|true)$ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is a boolean yes/no value
# Arguments:
#   $1 - Value to check
# Returns:
#   Boolean
#########################
is_yes_no_value() {
    local -r bool="${1:-}"
    if [[ "$bool" =~ ^(yes|no)$ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is a boolean true/false value
# Arguments:
#   $1 - Value to check
# Returns:
#   Boolean
#########################
is_true_false_value() {
    local -r bool="${1:-}"
    if [[ "$bool" =~ ^(true|false)$ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is an integer
# Arguments:
#   $1 - Value to check
# Returns:
#   Boolean
#########################
is_int() {
    local -r int="${1:?missing value}"
    if [[ "$int" =~ ^-?[0-9]+ ]]; then
        true
    else
        false
    fi
}

########################
# Check if the provided argument is an empty string or not defined
# Arguments:
#   $1 - Value to check
# Returns:
#   Boolean
#########################
is_empty_value() {
    local -r val="${1:-}"
    if [[ -z "$val" ]]; then
        true
    else
        false
    fi
}

########################
# Validate if the provided argument is a valid port
# Arguments:
#   $1 - Port to validate
# Returns:
#   Boolean and error message
#########################
validate_port() {
    local value
    local unprivileged=0

    # Parse flags
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -unprivileged)
                unprivileged=1
                ;;
            --)
                shift
                break
                ;;
            -*)
                stderr_print "unrecognized flag $1"
                return 1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    if [[ "$#" -gt 1 ]]; then
        echo "too many arguments provided"
        return 2
    elif [[ "$#" -eq 0 ]]; then
        stderr_print "missing port argument"
        return 1
    else
        value=$1
    fi

    if [[ -z "$value" ]]; then
        echo "the value is empty"
        return 1
    else
        if ! is_int "$value"; then
            echo "value is not an integer"
            return 2
        elif [[ "$value" -lt 0 ]]; then
            echo "negative value provided"
            return 2
        elif [[ "$value" -gt 65535 ]]; then
            echo "requested port is greater than 65535"
            return 2
        elif [[ "$unprivileged" = 1 && "$value" -lt 1024 ]]; then
            echo "privileged port requested"
            return 3
        fi
    fi
}

########################
# Read the provided pid file and returns a PID
# Arguments:
#   $1 - Pid file
# Returns:
#   PID
#########################
get_pid_from_file() {
    local pid_file="${1:?pid file is missing}"

    if [[ -f "$pid_file" ]]; then
        if [[ -n "$(< "$pid_file")" ]] && [[ "$(< "$pid_file")" -gt 0 ]]; then
            echo "$(< "$pid_file")"
        fi
    fi
}

########################
# Check if a provided PID corresponds to a running service
# Arguments:
#   $1 - PID
# Returns:
#   Boolean
#########################
is_service_running() {
    local pid="${1:?pid is missing}"

    kill -0 "$pid" 2>/dev/null
}

########################
# Checks whether a directory is empty or not
# arguments:
#   $1 - directory
# returns:
#   boolean
#########################
is_dir_empty() {
    local -r path="${1:?missing directory}"
    # Calculate real path in order to avoid issues with symlinks
    local -r dir="$(realpath "$path")"
    if [[ ! -e "$dir" ]] || [[ -z "$(ls -A "$dir")" ]]; then
        true
    else
        false
    fi
}

########################
# Validate if the provided argument is a valid IPv6 address
# Arguments:
#   $1 - IP to validate
# Returns:
#   Boolean
#########################
validate_ipv6() {
    local ip="${1:?ip is missing}"
    local stat=1
    local full_address_regex='^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$'
    local short_address_regex='^((([0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}){0,6}::(([0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}){0,6})$'

    if [[ $ip =~ $full_address_regex || $ip =~ $short_address_regex || $ip == "::" ]]; then
        stat=0
    fi
    return $stat
}

########################
# Get machine's IP
# Arguments:
#   None
# Returns:
#   Machine IP
#########################
get_machine_ip() {
    local -a ip_addresses
    local hostname
    hostname="$(hostname)"
    read -r -a ip_addresses <<< "$(dns_lookup "$hostname" | xargs echo)"
    if [[ "${#ip_addresses[@]}" -gt 1 ]]; then
        warn "Found more than one IP address associated to hostname ${hostname}: ${ip_addresses[*]}, will use ${ip_addresses[0]}"
    elif [[ "${#ip_addresses[@]}" -lt 1 ]]; then
        error "Could not find any IP address associated to hostname ${hostname}"
        exit 1
    fi
    # Check if the first IP address is IPv6 to add brackets
    if validate_ipv6 "${ip_addresses[0]}" ; then
        echo "[${ip_addresses[0]}]"
    else
        echo "${ip_addresses[0]}"
    fi
}

########################
# Stop a service by sending a termination signal to its pid
# Arguments:
#   $1 - Pid file
#   $2 - Signal number (optional)
# Returns:
#   None
#########################
stop_service_using_pid() {
    local pid_file="${1:?pid file is missing}"
    local signal="${2:-}"
    local pid

    pid="$(get_pid_from_file "$pid_file")"
    [[ -z "$pid" ]] || ! is_service_running "$pid" && return

    if [[ -n "$signal" ]]; then
        kill "-${signal}" "$pid"
    else
        kill "$pid"
    fi

    local counter=10
    while [[ "$counter" -ne 0 ]] && is_service_running "$pid"; do
        sleep 1
        counter=$((counter - 1))
    done
}

########################
# Gets semantic version
# Arguments:
#   $1 - version: string to extract major.minor.patch
#   $2 - section: 1 to extract major, 2 to extract minor, 3 to extract patch
# Returns:
#   array with the major, minor and release
#########################
get_sematic_version () {
    local version="${1:?version is required}"
    local section="${2:?section is required}"
    local -a version_sections

    #Regex to parse versions: x.y.z
    local -r regex='([0-9]+)(\.([0-9]+)(\.([0-9]+))?)?'

    if [[ "$version" =~ $regex ]]; then
        local i=1
        local j=1
        local n=${#BASH_REMATCH[*]}

        while [[ $i -lt $n ]]; do
            if [[ -n "${BASH_REMATCH[$i]}" ]] && [[ "${BASH_REMATCH[$i]:0:1}" != '.' ]];  then
                version_sections[j]="${BASH_REMATCH[$i]}"
                ((j++))
            fi
            ((i++))
        done

        local number_regex='^[0-9]+$'
        if [[ "$section" =~ $number_regex ]] && (( section > 0 )) && (( section <= 3 )); then
             echo "${version_sections[$section]}"
             return
        else
            stderr_print "Section allowed values are: 1, 2, and 3"
            return 1
        fi
    fi
}
