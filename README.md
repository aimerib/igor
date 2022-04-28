# Igor

Igor is a very simple dotfile management system accompanied by a script that
registers files to be tracked, and handles moving them into the same folder the
script is located. Additionally, Igor will also create a symbolic link to the
file's original location.

## Methodology

When using Igor to track your dotfiles you should use `igor -add file_name` to
start tracking that file. Every time you start or stop tracking a file you
should commit the changes to this repository. You should also commit any changes
made to tracked files in order for them to be replicated across your systems.
Once a change is made and pushed to github, from any other systems where you are
using Igor to track your dotfiles you can `git pull` from inside the repository
folder to update your files with the most up to date revision.

## Setup

For Igor to be most effective, the best way to setup your system is to have an
alias for Igor in your shell profile or `$PATH`.

### Example

---

Assuming this repository was cloned to $HOME/igor

```sh
echo "igor=$HOME/igor.sh" >> .bashrc # if you use bash
# or
echo "igor=$HOME/igor.sh" >> .zshrc # if you use zsh
```

## Tracking new files

Once Igor is in your `$PATH` you can start tracking your dotfiles. To do so,
simply tell `igor` to add it to the list of files
being tracked.

### Example

---

```sh
igor --add my_file.txt
# now the file called my_file.txt was moved to $HOME/igor
# and a symlink pointo to it was created in the current folder where this file
# is located
# The file $HOME/igor/tracked-files now has an entry for my_file=/current/folder
```

## Restoring tracked files

When you want to restore your dotfiles to a new system, or fix issues with the
existing symlinks you can tell `igor` to restore the files.
Igor will create symbolic links to the files existing in the version controlled
folder where the script is running from. Igor uses the tracked-files list to
determine where the symlinks should point to.

### Example

---

```sh
igor --restore
```

## Stop tracking a file

When you decide you no longer want to track a specific file, you can simply tell
`igor` to remove it from the list of tracked files. Igor will remove the symlink
to the tracked file, and move the file from the version controlled folder into
the original location of that file according to what was saved in tracked-files.

### Example

---

```sh
igor --remove my_file.txt
# at this point `igor` has removed the symlink to this file and moved the file
# back to its original location.
```
