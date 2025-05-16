#!/bin/bash
#
# Script Name: diskspace.sh
# Description: Disk Space Analyzer with Reporting
#              This script analyzes disk space usage and generates reports.
#
# Features:
#   - Core Analysis: Uses du command
#   - Options: Target directory, max depth, units
#   - Filters: Exclude directories/file types, modified time
#   - Sorting: Size, Name, Last Modified Time
#   - Filtering: Size threshold
#   - Reporting: Plain text, CSV, HTML, JSON
#   - Configuration:  (Basic, within the script)
#
# Key Learning:
#   - Shell scripting
#   - Advanced use of du
#   - Data manipulation with awk and sed
#   - Report generation
#   - File system concepts
#   - Data visualization (optional, basic text)
#

# Configuration (Can be moved to an external file for more flexibility)
report_formats=("text" "csv" "html" "json")
default_report_format="text"
excluded_dirs=("/proc" "/dev" "/sys" "/run")  # Example excluded directories
# Function to check if a directory should be excluded
is_excluded() {
    local dir_to_check="$1"
    for excluded_dir in "${excluded_dirs[@]}"; do
        if [[ "$dir_to_check" == "$excluded_dir" ]]; then
            return 0 # Excluded
        fi
    done
    return 1 # Not excluded
}

# Function to generate the disk usage report
generate_report() {
    local target_dir="$1"
    local max_depth="$2"
    local units="$3"
    local report_format="$4"
    local sort_option="$5"
    local size_threshold="$6"
    local modified_within="$7"
    local excluded_dirs_arg

    # Default values
    [[ -z "$target_dir" ]] && target_dir="."
    [[ -z "$max_depth" ]] && max_depth=0 # 0 means no limit for du
    [[ -z "$units" ]] && units="M"
    [[ -z "$report_format" ]] && report_format="$default_report_format"
    [[ -z "$sort_option" ]] && sort_option="name"
    [[ -z "$size_threshold" ]] && size_threshold=0

    # Validate report format
    if ! contains "${report_formats[@]}" "$report_format"; then
        echo "Error: Invalid report format '$report_format'.  Using default '$default_report_format'."
        report_format="$default_report_format"
    fi

    # Validate units and set --block-size option for du
    local du_unit_option=""
    case "$units" in
        K|k) du_unit_option="--block-size=1K" ;;
        M|m) du_unit_option="--block-size=1M" ;;
        G|g) du_unit_option="--block-size=1G" ;;
        *)
            echo "Error: Invalid unit '$units'.  Using default 'M'."
            units="M"
            du_unit_option="--block-size=1M"
            ;;
    esac

     # Construct exclude arguments for the du command
    if [[ ${#excluded_dirs[@]} -gt 0 ]]; then
        excluded_dirs_arg=""
        for dir in "${excluded_dirs[@]}"; do
            excluded_dirs_arg="$excluded_dirs_arg --exclude='$dir'"
        done
    fi
    # Construct the du command
    local du_command="du $du_unit_option -d $max_depth $excluded_dirs_arg '$target_dir'"

     # Add modified time filter if provided
    local file_list=()
    if [[ -n "$modified_within" ]]; then
        while IFS= read -r file; do
            file_list+=("$file")
        done < <(find "$target_dir" -maxdepth "$max_depth" -type f -mtime "-$modified_within" -print0 | xargs -0 du "$du_unit_option" 2>/dev/null)
    else
        while IFS= read -r line; do
            file_list+=("$line")
        done < <("$du_command")
    fi

    # Check if du/find command was successful
    if [ ${#file_list[@]} -eq 0 ]; then
        echo "Error: No data returned from du/find command.  Check the target directory and options."
        return 1
    fi

    local total_space=0
    local data_lines=() # Array to store processed data lines
    # Process the raw data and filter by size
    for line in "${file_list[@]}"; do
        local size=$(echo "$line" | awk '{print $1}')
        local path=$(echo "$line" | awk '{$1=""; sub(/^ +/, ""); print}') #remove first field
        if [[ "$size" -ge "$size_threshold" ]]; then
            total_space=$((total_space + size))
            data_lines+=("$size $path") # Store size and path
        fi
    done

     # Sort the data
    case "$sort_option" in
        size_asc)
            sorted_data=($(printf "%s\n" "${data_lines[@]}" | sort -n))
            ;;
        size_desc)
             sorted_data=($(printf "%s\n" "${data_lines[@]}" | sort -nr))
            ;;
        name)
            sorted_data=($(printf "%s\n" "${data_lines[@]}" | sort -k2)) # Sort by path (2nd field)
            ;;
        mtime) #mtime sort option
            if [[ -n "$modified_within" ]]; then
                # When using mtime, the 'file_list' already contains size and path
                # We don't have direct mtime in this format, so sorting by name might be a reasonable fallback.
                sorted_data=($(printf "%s\n" "${data_lines[@]}" | sort -k2))
                echo "Warning: Sorting by modified time is not directly available with the current implementation when using the time filter. Sorting by name instead."
            else
                 # If no time filter, we can't directly sort by mtime from du output.
                 sorted_data=($(printf "%s\n" "${data_lines[@]}" | sort -k2))
                 echo "Warning: Sorting by modified time is not directly available with the current 'du' output format. Sorting by name instead."
            fi
            ;;
        *)
            sorted_data=($(printf "%s\n" "${data_lines[@]}" | sort -k2)) # Default to sort by name
            ;;
    esac

    # Generate the report
    local report_string=""
    report_string+="Disk Space Usage Report for '$target_dir'\n"
    report_string+="----------------------------------------\n"
    report_string+="Date: $(date)\n"
    report_string+="Target Directory: $target_dir\n"
    report_string+="Max Depth: $max_depth\n"
    report_string+="Units: $units\n"
    report_string+="Report Format: $report_format\n"
    report_string+="Sort Option: $sort_option\n"
    report_string+="Size Threshold: $size_threshold $units\n"
     if [[ -n "$modified_within" ]]; then
        report_string+="Modified Within: $modified_within days\n"
     fi
    report_string+="\n"

    case "$report_format" in
        text)
            report_string+="Total Space: $total_space $units\n"
            for line in "${sorted_data[@]}"; do
                local size=$(echo "$line" | awk '{print $1}')
                local path=$(echo "$line" | awk '{$1=""; sub(/^ +/, ""); print}')
                local percentage=$(awk "BEGIN { if ($total_space > 0) printf \'%.2f\', ($size / $total_space) * 100; else printf \'%.2f\', 0; }")
                report_string+="$size $units  - $path ($percentage%)\n"
            done
            ;;
        csv)
            report_string+="Size ($units),Path,Percentage\n"
            for line in "${sorted_data[@]}"; do
                 local size=$(echo "$line" | awk '{print $1}')
                local path=$(echo "$line" | awk '{$1=""; sub(/^ +/, ""); print}')
                local percentage=$(awk "BEGIN { if ($total_space > 0) printf \'%.2f\', ($size / $total_space) * 100; else printf \'%.2f\', 0; }")
                report_string+="$size,$path,$percentage\n"
            done
            report_string+="Total Space: $total_space $units\n"
            ;;
        html)
            report_string+="<!DOCTYPE html>\n"
            report_string+="<html>\n"
            report_string+="<head>\n"
            report_string+="<title>Disk Space Report</title>\n"
            report_string+="<style>\n"
            report_string+="  table { border-collapse: collapse; width: 100%; }\n"
            report_string+="  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }\n"
            report_string+="  tr:nth-child(even) { background-color: #f2f2f2; }\n"
            report_string+="</style>\n"
            report_string+="</head>\n"
            report_string+="<body>\n"
            report_string+="<h2>Disk Space Usage Report</h2>\n"
            report_string+="<p>Date: $(date)</p>\n"
            report_string+="<p>Target Directory: $target_dir</p>\n"
            report_string+="<p>Max Depth: $max_depth</p>\n"
            report_string+="<p>Units: $units</p>\n"
            report_string+="<p>Report Format: $report_format</p>\n"
            report_string+="<p>Sort Option: $sort_option</p>\n"
            report_string+="<p>Size Threshold: $size_threshold $units</p>\n"
             if [[ -n "$modified_within" ]]; then
                report_string+="<p>Modified Within: $modified_within days</p>\n"
             fi
            report_string+="<table>\n"
            report_string+="<tr><th>Size ($units)</th><th>Path</th><th>Percentage</th></tr>\n"
            for line in "${sorted_data[@]}"; do
                local size=$(echo "$line" | awk '{print $1}')
                local path=$(echo "$line" | awk '{$1=""; sub(/^ +/, ""); print}')
                local percentage=$(awk "BEGIN { if ($total_space > 0) printf \'%.2f\', ($size / $total_space) * 100; else printf \'%.2f\', 0; }")
                report_string+="<tr><td>$size</td><td>$path</td><td>$percentage</td></tr>\n"
            done
            report_string+="<tr><td><b>Total Space:</b></td><td>$total_space $units</td><td></td></tr>\n"
            report_string+="</table>\n"
            report_string+="</body>\n"
            report_string+="</html>\n"
            ;;
        json)
            report_string+="[\n"
            local first=true
            for line in "${sorted_data[@]}"; do
                local size=$(echo "$line" | awk '{print $1}')
                local path=$(echo "$line" | awk '{$1=""; sub(/^ +/, ""); print}')
                 local percentage=$(awk "BEGIN { if ($total_space > 0) printf \'%.2f\', ($size / $total_space) * 100; else printf \'%.2f\', 0; }")
                if $first; then
                    first=false
                else
                    report_string+=",\n"
                fi
                report_string+="{\n"
                report_string+="  \"size\": $size,\n"
                report_string+="  \"path\": \"$path\",\n"
                report_string+="  \"percentage\": \"$percentage\"\n"
                report_string+="}\n"
            done
            report_string+="],\n"
            report_string+="{\n"
            report_string+="  \"total_space\": \"$total_space $units\"\n"
            report_string+="}\n"
            ;;
        *)
            report_string+="Error: Invalid report format. Should not have reached here.\n"
            return 1
            ;;
    esac
    echo "$report_string"
}

# Helper function to check if an element exists in an array
contains() {
  local needle="$1"
  local haystack=("$@")
  shift
  for element in "${haystack[@]}"; do
    if [[ "$element" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

# Function to get basic disk information
get_disk_info() {
    local info_string=""
    info_string+="--- Disk Information ---\n"
    info_string+="$(lsblk -p | awk '{print $1, $2, $4, $6}' | column -t 2>/dev/null)\n"
    info_string+="\n"
    info_string+="--- Partition Information ---\n"
    info_string+="$(fdisk -l 2>/dev/null | grep '^/dev/')\n"
    info_string+="\n"
    info_string+="--- Mount Points ---\n"
    info_string+="$(mount | column -t)\n"
    echo "$info_string"
}


# Function to check disk usage and send an alert if it exceeds the threshold
check_disk_usage() {
    local usage=$(df -h | awk '$NF=="/"{print $5}' | tr -d '%' 2>/dev/null)
    local mount_point=$(df -h | awk '$NF=="/"{print $6}' 2>/dev/null)
    local alert_message=""

    if [[ "$usage" -gt "$1" ]]; then
        alert_message="Disk space on $mount_point is above $1% ($usage%).\n"
        # Removed email functionality
    else
        alert_message="Disk space on $mount_point is OK ($usage%).\n"
    fi
    echo "$alert_message"
}

# Function to monitor disk I/O performance using iostat
monitor_disk_performance() {
    local iostat_output=""
    iostat_output+="--- Disk I/O Performance (iostat) ---\n"
    iostat_output+="$(iostat -p sda1 1 1 2>/dev/null)\n"
    echo "$iostat_output"
}

# iostat -d -p sda 5 5 2