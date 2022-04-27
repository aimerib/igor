#!/bin/bash

set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

warning_header=$(tput setab 227 setaf 0 bold)
warning_text=$(tput setaf 227 setab 0 bold)
inform_header=$(tput setab 20 setaf 254 bold)
inform_text=$(tput setaf 20 setab 254 bold)
yell_header=$(tput setab 160 setaf 226 bold)
yell_text=$(tput setaf 160 setab 0 bold)
result_header=$(tput setab 118 setaf 0 bold)
result_text=$(tput setaf 118 setab 0 bold)
message_text=$(tput setaf 255 setab 0)
normal=$(tput sgr0)

ceildiv() { echo $((("$1" + "$2" - 1) / "$2")); }

# Use this to ensure messages fit in most terminals
# we define the maximum size here
max_message_size=80
# and use this array to fool printf in using our variable
# for a range since we can't use variable expansion before the brace expansion
# is evaluated.
message_size=()
for ((i = 1; i <= "$max_message_size"; i++)); do message_size+=("$i"); done

separator="$(printf "%0.s=" "${message_size[@]}")"

warn() {
  text=$(echo "$1" | fold -w "$max_message_size" -)
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, I have an important message!\e[K%s\n" "${warning_header}" "${normal}" "${warning_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "\n%s\n\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

inform() {
  text=$(echo "$1" | fold -w "$max_message_size" -)
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, this might interest you:\e[K%s\n" "${inform_header}" "${normal}" "${inform_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "%s\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

yell() {
  text=$(echo "$1" | fold -w "$max_message_size" -)
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, attention!\e[K%s\n" "${yell_header}" "${normal}" "${yell_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "%s\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

result() {
  text=$(echo "$1" | fold -w "$max_message_size" -)
  printf "\n%s\e[K" "$message_text"
  printf "%s" "$separator"
  printf "\n%s\xC2\xA0Igor\xC2\xA0%s%s Master, here are the results:\e[K%s\n" "${result_header}" "${normal}" "${result_text}" "${normal}"
  printf "%s\e[K" "$message_text"
  printf "%s\n" "$text"
  printf "%s" "$separator"
  printf "%s\n\n" "${normal}"
}

usage() {
  cat <<EOF
This is how I can help: $(
    basename "${BASH_SOURCE[0]}"
  ) [-h] -p param_value arg1 [arg2...]

Script description here.

Available options:

-h, --help                Print this help and exit
-a, --add     <file_name> Adds a file to the .dotfiles repository and
                          links file to its original location.
-r, --remove  <file_name> Moves file back to its original location and
                          removes links to file.
EOF
}

# Entry point of the script
add_file() {
  echo "$param"
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
  mv "$PWD/$param" "$script_dir"
  ln -s "$script_dir/$param" "$PWD/$param"
  ls -la "$PWD/$param"
  exit 0
}

remove_file() {
  echo "$param"
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

  rm "$PWD/$param"
  mv "$script_dir/$param" "$PWD"
  ls -la "$PWD/$param"
  exit 0
}

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
    "-r" | "--remove")
      param="${2-}"
      shift
      remove_file
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
