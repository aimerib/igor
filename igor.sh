#!/bin/bash
# Fail fast
set -Eeuo pipefail
# igor is meant to stay inside the same folder as the
# repository. We save it here for use later.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# Set terminal colors for messages
warning_header=$(tput setab 227 setaf 0 bold)
warning_text=$(tput setaf 227 setab 0 bold)
inform_header=$(tput setab 20 setaf 254 bold)
inform_text=$(tput setaf 243 setab 0 bold)
yell_header=$(tput setab 160 setaf 226 bold)
yell_text=$(tput setaf 160 setab 0 bold)
result_header=$(tput setab 118 setaf 0 bold)
result_text=$(tput setaf 118 setab 0 bold)
message_text=$(tput setaf 255 setab 0)
normal=$(tput sgr0)

# Use this to ensure messages fit in most terminals
# we define the maximum size here
max_message_size=80
# and use this array to fool printf in using our variable
# for a range since we can't use variable expansion before the brace expansion
# is evaluated.
message_size=()
for ((i = 1; i <= "$max_message_size"; i++)); do message_size+=("$i"); done
# message_size is the maximum width we will use for messages
# and can be used to calculate the maximum number of times to
# repeat a separator charater when printing a message
separator="$(printf "%0.s=" "${message_size[@]}")"

# TODO refactor messaging system
warn() {
  # max_message_size is also used here to wrap any text
  # with length over that size
  text=$(echo "$1" | fold -w "$max_message_size" -)

  # Mostly black magic here.
  # basically we use tput to instruct the terminal to
  # switch the color scheme, then reseting to normal
  # and repeating the process for each color change
  # applied. \e[K is used to apply the bg style to the
  # end of the line.
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, I have an important message!\e[K%s\n" "${warning_header}" "${normal}" "${warning_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "\n%b\e[K\n\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

inform() {
  # max_message_size is also used here to wrap any text
  # with length over that size
  text=$(echo "$1" | fold -w "$max_message_size" -)

  # Mostly black magic here.
  # basically we use tput to instruct the terminal to
  # switch the color scheme, then reseting to normal
  # and repeating the process for each color change
  # applied. \e[K is used to apply the bg style to the
  # end of the line.
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, this might interest you:\e[K%s\n" "${inform_header}" "${normal}" "${inform_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "\n%b\e[K\n\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

yell() {
  # max_message_size is also used here to wrap any text
  # with length over that size
  text=$(echo "$1" | fold -w "$max_message_size" -)

  # Mostly black magic here.
  # basically we use tput to instruct the terminal to
  # switch the color scheme, then reseting to normal
  # and repeating the process for each color change
  # applied. \e[K is used to apply the bg style to the
  # end of the line.
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, attention!\e[K%s\n" "${yell_header}" "${normal}" "${yell_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "\n%b\e[K\n\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

result() {
  # max_message_size is also used here to wrap any text
  # with length over that size
  text=$(echo "$1" | fold -w "$max_message_size" -)

  # Mostly black magic here.
  # basically we use tput to instruct the terminal to
  # switch the color scheme, then reseting to normal
  # and repeating the process for each color change
  # applied. \e[K is used to apply the bg style to the
  # end of the line.
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, here are the results:\e[K%s\n" "${result_header}" "${normal}" "${result_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "\n%b\e[K\n\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

usage() {
  cat <<EOF
This is how I can help: $(
    basename "${BASH_SOURCE[0]}"
  ) [-h] -p param_value arg1 [arg2...]

Igor can help managing dotfiles by moving the specified dotfile
to the same folder this script is located in, and creating a
symbolic link to the file in it's original location.
The folder where the igor script is located should be version
controlled.
This script generates a file called tracked-files that should
be checked into version control as well. This file functions as
the database that igor uses for tracking where each symbolic
link needs to be created when restoring the dotfiles

Available options:

-h, --help                   Print this help and exit
-a, --add       <file_name>  Adds a file to the .dotfiles repository and
                             links file to its original location.
-R, --remove    <file_name>  Moves file back to its original location and
                             removes links to file.
-r, --restore  [<file_name>] Restore dotfiles from repository. This 
                             is done by creating symbolic links to the
                             files in this repository from the locations
                             where the files were originally located.
EOF
}

# We add files to the version controlled folder here.
# We also store the file name and original folder location
# in the tracked-files here.
add_file() {
  # Sanity check. Does file exist?
  [ ! -f "$PWD/$param" ] && {
    yell "I can't find $param inside $PWD. Please try again with the right name"
    exit 1
  }
  # Sanity check. Is file a symbolic link already
  [ -h "$PWD/$param" ] && {
    yell "$param seems to already be a symbolic link. I don't want to do this."
    exit 1
  }
  # move original file to the folder where this script is located
  mv "$PWD/$param" "$script_dir"
  # create symbolic link to original file
  ln -s "$script_dir/$param" "$PWD/$param"
  # add name and location to the list of files igor is managing
  echo "$param=$PWD" >>"$script_dir/tracked-files"
  result "I am now managing $PWD/$param"
  exit 0
}

# We stop tracking files from this function.
remove_file() {
  # Sanity check. Does file exist in .dotfiles?
  [ ! -f "$script_dir/$param" ] && {
    yell "I can't find $param inside $script_dir. Are you sure I'm managing that file?"
    exit 1
  }
  # Sanity check. Is file a symbolic link?
  [ ! -h "$PWD/$param" ] && {
    yell "I does't seem like $param is a symbolic link. I don't want to do this."
    exit 1
  }
  # remove old symlink
  rm "$PWD/$param"
  # the script is expecting to receive this command from the same folder where
  # the symlink for the file we want to stop tracking is located.
  # move the tracked file to the current folder where the symlink was located
  mv "$script_dir/$param" "$PWD"
  # remove the entry for this file from the list of tracked files
  # we need a temporary file here to hold the results of grep
  grep -v "${param}=${PWD}" "$script_dir/tracked-files" >"$script_dir/tracked-files.tmp"
  # clean up the temp file
  mv "$script_dir/tracked-files.tmp" "$script_dir/tracked-files"
  result "I stopped managing $PWD/$param and restored the original file to it's location."
  exit 0
}

# We restore symbolic links to tracked files from here
# This function is meant to be use when restoring a new
# system, but can also be use to restore broken or deleted
# symlinks too
restore_from_repo() {
  # this function will move all files that already exist in the
  # current system that conflict with tracked files to a backup
  # folder called .config-backup.
  # if .config-backup folder doesn't exist, create one
  mkdir -p "$HOME/.config-backup"
  backup_folder="$HOME/.config-backup"
  # create a new array to track files restored successfully
  declare -a restored_files
  # read tracked-files one line at the time
  while IFS= read -r line; do
    # extract the file name from start of string up to delimiter =.
    file_name=${line%%=*}
    # delete file name AND next separator =, from $line to get path
    # to folder.
    folder="${line#"$file_name"=}"
    full_path="$folder/$file_name"
    # Sanity check. Does file already exist? Back it up
    [ -f "$full_path" ] && {
      mv "$full_path" "$backup_folder"
    }
    # create a new symbolic link to location of original file
    ln -s "$script_dir/$file_name" "$full_path"
    # add name and folder of current file to the array for
    # reporting
    restored_files+=("name: $file_name -> folder: $folder")
  done <<<"$(cat "$script_dir/tracked-files")"
  # transfor array into string separated by new lines
  restored_files_text=$(printf "%s\n" "${restored_files[@]}")
  result "I've restored the following:\n\n${restored_files_text}"
  exit 0
}

# function used for debugging
print_folder() {
  inform "Current folder: $PWD\nScript folder: $script_dir"
}

# Check if we have all required parameters
# and call the function corresponding to the
# argument used
parse_params() {
  args=("$@")

  # check required params and arguments
  [ ${#args[@]} -eq 0 ] && {
    warn "You didn't tell me what to do, master."
    usage
    return 1
  }

  # default values of variables set from params
  param=''

  while :; do
    case "${1-}" in
    "-h" | "--help")
      usage
      exit 0
      ;;
    "-a" | "--add")
      param="${2-}"
      shift
      add_file
      ;;
    "-r" | "--restore")
      param="${2-}"
      shift
      restore_from_repo
      ;;
    "-R" | "--remove")
      param="${2-}"
      shift
      remove_file
      ;;
    "--print-folder")
      shift
      print_folder
      exit 0
      ;;
    -?*)
      warn "I don't understand the option: $1"
      usage
      exit 1
      ;;
    *) break ;;
    esac
    shift
  done
  return 0
}

parse_params "$@"
