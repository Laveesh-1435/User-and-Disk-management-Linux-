#!/bin/bash
#
# Script Name: usermgmt.sh
# Description: User Management Toolkit (Simplified)
#              This script provides functions to manage users.
#
# Features:
#   - adduserplus:  Add a new user
#   - deluserplus:  Delete an existing user
#   - userinfo:     Display user information
#
# Key Learning:
#   - Shell scripting (bash)
#   - File manipulation (sed, awk, grep)
#   - System files (/etc/passwd, /etc/shadow)
#   - User management commands (useradd, usermod, userdel)
#   - Security best practices
#

# Logging function
log_activity() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S'): $message" #>> /var/log/usermgmt.log
}

# Function: adduserplus
# Description: Adds a new user with validation and logging.
# Input:
#   - Username
#   - Full Name
#
adduserplus() {
    local username="$1"
    local fullname="$2"

    # Input validation
    if [[ -z "$username" || -z "$fullname" ]]; then
        echo "Error: Username and Full Name are required."
        log_activity "Add User Failed: Username or Full Name missing"
        return 1
    fi

    if id "$username" &>/dev/null; then
        echo "Error: User '$username' already exists."
        log_activity "Add User Failed: User '$username' exists"
        return 1
    fi

    # Create the user
    if ! sudo useradd "$username"; then
        echo "Error: Failed to create user '$username'."
        log_activity "Add User Failed: useradd $username"
        return 1
    fi

    # Set the password
    echo -n "Enter password for $username: "
    read -s password
    if ! echo "$username:$password" | sudo chpasswd; then
        echo "Error: Failed to set password for '$username'."
        # Rollback: Delete the user if password setting fails
        sudo userdel "$username"
        log_activity "Add User Failed: chpasswd $username"
        return 1
    fi

    # Set the full name
    if ! sudo usermod -c "$fullname" "$username"; then
        echo "Error: Failed to set full name for '$username'."
        # Rollback: Delete the user if setting full name fails
        sudo userdel "$username"
        log_activity "Add User Failed: usermod -c $fullname $username"
        return 1
    fi

    echo "User '$username' created successfully."
    log_activity "User '$username' created"
    return 0
}


# Function: deluserplus
# Description: Deletes a user with confirmation and options.
# Input:
#   - Username
# Options:
#   - -r: Remove home directory and mail spool
#   - -a <archive_dir>: Archive home directory before deletion
#
deluserplus() {
    local username="$1"
    local remove_home=false
    local archive_dir=""
    local opt

    # Process options
    while getopts "ra:" opt; do
        case "$opt" in
            r)
                remove_home=true
                ;;
            a)
                archive_dir="$OPTARG"
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                return 1
                ;;
        esac
    done
    shift $((OPTIND -1)) #shift to consume the options

    # Check if username is provided
    if [[ -z "$username" ]]; then
        echo "Error: Username is required."
        log_activity "Delete User Failed: Username missing"
        return 1
    fi

    # Check if the user exists
    if ! id "$username" &>/dev/null; then
        echo "Error: User '$username' does not exist."
        log_activity "Delete User Failed: User '$username' does not exist"
        return 1
    fi

    # Prompt for confirmation
    read -p "Are you sure you want to delete user '$username'? (y/N) " -n 1 answer
    echo  # Add a newline after the user's response
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled."
        log_activity "Delete User Cancelled: User '$username'"
        return 0
    fi

    # Archive home directory if requested
    if [[ -n "$archive_dir" ]]; then
        if [[ ! -d "$archive_dir" ]]; then
            echo "Error: Archive directory '$archive_dir' does not exist."
            log_activity "Delete User Failed: Archive directory '$archive_dir' does not exist"
            return 1
        fi
        sudo tar -czf "$archive_dir/$username.tar.gz" "/home/$username"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to archive home directory."
            log_activity "Delete User Failed: Failed to archive home directory of  '$username'"
            return 1
        fi
        echo "Home directory archived to $archive_dir/$username.tar.gz"
        log_activity "Home directory of '$username' archived to $archive_dir/$username.tar.gz"
    fi

    # Delete the user
    local userdel_cmd="sudo userdel"
    if $remove_home; then
        userdel_cmd="$userdel_cmd -r"
    fi

    if ! $userdel_cmd "$username"; then
        echo "Error: Failed to delete user '$username'."
        log_activity "Delete User Failed: $userdel_cmd $username"
        return 1
    fi

    echo "User '$username' deleted successfully."
    log_activity "User '$username' deleted"
    return 0
}


# Function: userinfo
# Description: Retrieves and displays user information.
# Input:
#   - Username
#
userinfo() {
    local username="$1"

    # Check if username is provided
    if [[ -z "$username" ]]; then
        echo "Error: Username is required."
        log_activity "User Info Failed: Username missing"
        return 1
    fi

    # Check if the user exists
    if ! id "$username" &>/dev/null; then
        echo "Error: User '$username' does not exist."
        log_activity "User Info Failed: User '$username' does not exist"
        return 1
    fi

    # Get information from /etc/passwd
    local passwd_info=$(grep "^$username:" /etc/passwd)
    if [[ -n "$passwd_info" ]]; then
        IFS=":" read -r user login_uid gid homedir shell <<<"$passwd_info"
        echo "Username: $user"
        echo "UID:      $login_uid"
        echo "GID:      $gid"
        echo "Home directory: $homedir"
        echo "Login shell:    $shell"
    else
        echo "Error: Could not retrieve user information from /etc/passwd."
        log_activity "User Info Failed: Could not retrieve user information from /etc/passwd for '$username'"
        return 1
    fi

    # Get last login time
    local last_login=$(sudo lastlog -u "$username" | tail -n 1 | awk '{print $5, $6, $7, $8, $9}') # Improved
    if [[ "$last_login" != "Never logged" ]]; then
       echo "Last login:   $last_login"
    else
       echo "Last login:   Never logged in"
    fi
    log_activity "User Info displayed for '$username'"


    local username="$1"
    id "$username" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "Username: $(id -un "$username")"
        echo "User ID: $(id -u "$username")"
        echo "Group ID: $(id -g "$username")"
        echo "Groups: $(groups "$username")"
        echo "Home Directory: $(getent passwd "$username" | cut -d: -f6)"
        echo "Shell: $(getent passwd "$username" | cut -d: -f7)"
    else
        echo "User '$username' not found."
    fi
}




#
# Main script logic (for testing)
#
# if [[ $0 == "$BASH_SOURCE" ]]; then # Only execute if script is run directly. Prevents running if sourced.
#     echo "User Management Toolkit"
#     echo "------------------------"
#
#     # Example usage (for testing)
#     adduserplus "testuser" "Test User"
#     userinfo "testuser"
#     deluserplus "testuser" -r
#
#     echo "Exiting..."
# fi
