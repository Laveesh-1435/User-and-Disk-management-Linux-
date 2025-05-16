#!/bin/bash
#
# Script Name: gui.sh
# Description:  Provides a whiptail GUI menu to access usermgmt.sh and diskspace.sh
#

# Check if whiptail is installed
if ! command -v whiptail &>/dev/null; then
    echo "Error: whiptail is not installed. Please install it to use this script."
    exit 1
fi

# Source the other scripts (assuming they are in the same directory)
# If the scripts are in a different directory, you'll need to adjust the paths.
source ./usermgmt.sh
source ./diskspace.sh

# Function to display the main menu and call the appropriate scripts/functions
main_menu() {
    while true; do
        choice=$(whiptail --title "System Management Toolkit" \
                            --menu "Choose an option:" \
                            --clear \
                            20 60 10 \
                            1 "User Management" \
                            2 "Disk Space Analysis" \
                            3 "System Information" \
                            4 "Exit" 3>&1 1>&2 2>&3)

        case "$choice" in
            "1")
                user_management_menu
                ;;
            "2")
                disk_space_menu  # New Disk Space Menu
                ;;
            "3")
                system_information_menu # New menu for system info
                ;;
            "4")
                echo "Exiting..."
                exit 0
                ;;
            "")
                # Handle Esc or Cancel
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice: $choice"
                ;;
        esac
    done
}


# Function to display the User Management Menu
user_management_menu() {
    while true; do
        choice=$(whiptail --title "User Management" \
                           --menu "Choose an option:" \
                           --clear \
                           20 70 10 \
                           1 "Add User" \
                           2 "Delete User" \
                           3 "User Info" \
                           4 "Back to Main Menu" 3>&1 1>&2 2>&3)

        case "$choice" in
            "1")
                # Get user input using whiptail
                username=$(whiptail --inputbox "Enter username:" 10 60 --title "Add User" 3>&1 1>&2 2>&3)
                fullname=$(whiptail --inputbox "Enter full name:" 10 60 --title "Add User" 3>&1 1>&2 2>&3)
                password=$(whiptail --inputbox "Enter password:" 10 60 --title "Add User" --password 3>&1 1>&2 2>&3)


                # Check for empty input
                if [[ -z "$username" || -z "$fullname" || -z "$password" ]]; then
                    whiptail --msgbox "Error: Username, Full Name, and Password are required." 10 60
                else
                    adduserplus "$username" "$fullname" "$password" # Pass the password to adduserplus
                    if [ $? -eq 0 ]; then
                        whiptail --msgbox "User added successfully." 10 60
                    else
                        whiptail --msgbox "User add failed." 10 60
                    fi
                fi
                ;;
            "2")
                username=$(whiptail --inputbox "Enter username to delete:" 10 60 --title "Delete User" 3>&1 1>&2 2>&3)
                if [[ -z "$username" ]]; then
                    whiptail --msgbox "Error: Username  is required." 10 60
                else
                    remove_home=$(whiptail --yesno "Remove home directory and mail spool?" 10 60 --title "Delete User" 3>&1 1>&2 2>&3)
                    if [ $remove_home -eq 0 ]; then
                        deluserplus "$username" -r
                        if [ $? -eq 0 ]; then
                            whiptail --msgbox "User deleted successfully." 10 60
                        else
                            whiptail --msgbox "User deletion failed." 10 60
                        fi
                    else
                        deluserplus "$username"
                        if [ $? -eq 0 ]; then
                            whiptail --msgbox "User deleted successfully." 10 60
                        else
                            whiptail --msgbox "User deletion failed." 10 60
                        fi
                    fi
                fi
                ;;
            "3")
                username=$(whiptail --inputbox "Enter username to get info:" 10 60 --title "User Info" 3>&1 1>&2 2>&3)
                if [[ -z "$username" ]]; then
                    whiptail --msgbox "Error: Username is required." 10 60
                else
                    user_info_text=$(userinfo "$username")  # Capture the output
                    if [ $? -eq 0 ]; then
                        whiptail --msgbox "$user_info_text" 20 60 --title "User Information"
                    else
                        whiptail --msgbox "Error: Could not retrieve user information." 10 60
                    fi
                fi
                ;;
            "4")
                break
                ;;
            "")
                break
                ;;
            *)
                whiptail --msgbox "Invalid choice: $choice" 10 60
                ;;
        esac
    done
}           

# Function to display the Disk Space Analysis Menu
disk_space_menu() {
    local target_dir default_depth default_units default_report default_sort default_threshold default_modified

    target_dir=$(whiptail --inputbox "Enter target directory:" 10 60 "." --title "Disk Space Analysis" 3>&1 1>&2 2>&3)
    default_depth=$(whiptail --inputbox "Enter maximum depth (0 for all):" 10 60 "0" --title "Disk Space Analysis" 3>&1 1>&2 2>&3)
    default_units=$(whiptail --menu "Choose units:" 15 60 4 \
                                   "K" "Kilobytes" \
                                   "M" "Megabytes" \
                                   "G" "Gigabytes" --title "Disk Space Analysis" 3>&1 1>&2 2>&3)
    default_report=$(whiptail --menu "Choose report format:" 15 60 4 \
                                    "text" "Plain text" \
                                    "csv" "CSV" \
                                    "html" "HTML" \
                                    "json" "JSON" --title "Disk Space Analysis" 3>&1 1>&2 2>&3)
    default_sort=$(whiptail --menu "Sort by:" 15 60 4 \
                                  "name" "Name" \
                                  "size_asc" "Size (ascending)" \
                                  "size_desc" "Size (descending)" \
                                  "mtime" "Last Modified Time" --title "Disk Space Analysis" 3>&1 1>&2 2>&3)
    default_threshold=$(whiptail --inputbox "Show files/dirs above size (in selected units, 0 for all):" 10 60 "0" --title "Disk Space Analysis" 3>&1 1>&2 2>&3)
    default_modified=$(whiptail --inputbox "Show files modified within (days, leave empty for all):" 10 60 "" --title "Disk Space Analysis" 3>&1 1>&2 2>&3)


    if [[ -n "$target_dir" && -n "$default_depth" && -n "$default_units" && -n "$default_report" && -n "$default_sort" && -n "$default_threshold" ]]; then
        generate_report "$target_dir" "$default_depth" "$default_units" "$default_report" "$default_sort" "$default_threshold" "$default_modified" | less
    fi
}


# Function to display System Information Menu
system_information_menu() {
    while true; do
        choice=$(whiptail --title "System Information" \
                           --menu "Choose an option:" \
                           --clear \
                           15 60 5  \
                           1 "Disk Information" \
                           2 "Check Disk Usage" \
                           3 "Monitor Disk Performance" \
                           4 "Back to Main Menu" 3>&1 1>&2 2>&3)

        case "$choice" in
            "1")
                get_disk_info | less
                ;;
            "2")
                # Removed threshold prompt
                output=$(check_disk_usage "0") # Using "0" as dummy threshold
                echo "$output" | less
                ;;
            "3")
                monitor_disk_performance | less
                ;;
            "4")
                break
                ;;
            "")
                break
                ;;
            *)
                echo "Invalid choice: $choice"
                ;;
        esac
    done
}

# Start the main menu
main_menu