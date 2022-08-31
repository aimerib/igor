use std::{
    cell::RefCell,
    env, fs,
    path::{Path, PathBuf},
    rc::Rc,
};

use directories::{ProjectDirs, UserDirs};
use read_input::{prelude::input, shortcut::with_display, InputBuild};
use serde::{Deserialize, Serialize};

use anyhow::{Context, Ok, Result};
use std::io::Write;
use symlink::{remove_symlink_file, symlink_file};
extern crate text_io;

use clap::{Parser, Subcommand};

/// Igor is your helpful assistant to manage dotfiles
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct IgorArgs {
    #[clap(subcommand)]
    command: Option<IgorCommands>,
    #[clap(long)]
    show_config_path: bool,
}
#[derive(Subcommand, Debug)]
enum IgorCommands {
    /// Add a new file to be tracked by Igor
    Add { file_name: PathBuf },
    /// Creates a new version controlled folder for your dotfiles
    Init {
        /// If not specified, the dotfiles will be saved to a folder named .dotfiles in your home directory
        #[clap(long, short)]
        path: Option<String>,
        /// A name can be specified for the dotfiles folder along with the path if you want to name your
        /// dotfiles folder something other than .dotfiles
        #[clap(long, short)]
        name: Option<String>,
    },
}
#[derive(Debug)]
struct Igor {
    args: Rc<RefCell<IgorArgs>>,
    config: Config,
    path: PathBuf,
    config_file: PathBuf,
}

impl Igor {
    fn igor_project_config() -> ProjectDirs {
        ProjectDirs::from("com", "Slothcrew", "Igor")
            .context("Could not find config file")
            .unwrap()
    }
    fn new() -> Result<Self> {
        let config_folder = Igor::igor_project_config().config_dir().to_path_buf();
        // check that .dotfiles folder exists or create it in the home directory
        if !&config_folder.exists() {
            std::fs::create_dir_all(&config_folder)
                .context("Could not create igor config folder")?;
        }
        let config_path = config_folder.join("igorrc.yml");
        // if file doesn't exist, create it
        let mut config = Config::new()?;
        if !config_path.exists() {
            config.save_to_file()?;
        } else {
            config = Config::load_from_config_file()?;
        }

        let args = Rc::new(RefCell::new(IgorArgs::parse()));
        let path = env::current_dir().context("Failed to read current directory.")?;

        Ok(Igor {
            args,
            config,
            path,
            config_file: config_path,
        })
    }
    // Initializes the project, create folder, and config file
    fn init(path: &Path, name: &Option<String>) -> Result<()> {
        // We need to create a folder for the dotfiles, but the user might
        // have specified a folder name. If they did, we use that. Otherwise,
        // we use the default name.
        let full_dotfile_path = match name {
            Some(name) => path.join(name),
            None => path.join(".dotfiles"),
        };
        // We use the crate directories to generate OS compliant paths
        // for Igor config files.
        // On *nix systems, this is the ~/.config/appname folder.
        // On Windows, this is the %APPDATA%/Company/Appname folder.
        // On macOS, this is the ~/Library/Preferences/com.Company.Appname folder.
        let config_folder = Igor::igor_project_config().config_dir().to_path_buf();
        // check that .dotfiles folder exists or create it in the path
        if !&full_dotfile_path.exists() {
            std::fs::create_dir_all(&full_dotfile_path)
                .context("Could not create dotfiles folder")?;
        }
        // check that the config folder exists for igor, or create it
        if !&config_folder.exists() {
            std::fs::create_dir_all(&config_folder)
                .context("Could not create igor config folder")?;
        }
        // We want Igor to manage itself, so we actually create the config file
        // in the .dotfiles folder and symlink it to the config folder.
        // This variable represents the path in the symlink.
        let symlink_config_path = config_folder.join("igorrc.yml");
        // We also need to store the actual path to the .dotfile/igorrc.yml file
        let config_path = full_dotfile_path.join("igorrc.yml");
        // If symlink to config file exists, remove it and create a new one
        // otherwise, if the config file exists in the symlinked location, remove it
        // but ask the user first. Bedside manners are important.
        if symlink_config_path.exists() {
            // Path to symlink already exists. Is it a symlink or an actual file?
            if fs::symlink_metadata(&symlink_config_path)?
                .file_type()
                .is_symlink()
            {
                // It's a symlink, so ask the user if we can replace it.
                let user_answer: String = input()
                    .err_match(with_display)
                    .repeat_msg("Symlink for .igorrc.yml exists. Replace it? (y/n) ")
                    .get();
                // Do the dirty
                match user_answer.as_str() {
                    "y" | "Y" | "yes" | "Yes" | "YES" => {
                        remove_symlink_file(&symlink_config_path)?;
                        symlink_file(&config_path, &symlink_config_path)?;
                    }
                    "n" | "N" | "no" | "No" | "NO" => {
                        println!("Not replacing symlink");
                    }
                    _ => {
                        println!("Invalid answer");
                    }
                }
            } else {
                // Path exists, but it isn't a symlink. Do we want to track this file and symlink it?
                // This should never be the case if you're using this program, but just in case the user
                // has manually created the file, or has opted out of tracking the igorrc.yml file, we
                // should ask the user if we should move it to the tracked folder and symlink it.
                let user_answer = input::<String>()
                .err_match(with_display)
                .add_test(|x| matches!(x.as_str(), "y" | "Y" | "yes" | "Yes" | "YES" | "n" | "N" | "no" | "No" | "NO"))
                .repeat_msg("Config file exists in the symlinked location. Track it and replace it with a symlink? (y/n) ")
                .get();
                match user_answer.as_str() {
                    "y" | "Y" | "yes" | "Yes" | "YES" => {
                        fs::copy(&symlink_config_path, &config_path)
                            .context("Failed to move igorrc.yml to dotfiles folder")?;
                        fs::remove_file(&symlink_config_path)
                            .context("Could not remove symlink to config file")?;
                        symlink_file(&config_path, &symlink_config_path)?;
                    }
                    "n" | "N" | "no" | "No" | "NO" => {
                        println!("Not replacing symlink");
                    }
                    _ => {
                        println!("Invalid answer");
                    }
                }
            }
        } else {
            if !config_path.exists() {
                Config::new()?.save_to_file()?;
            }
            symlink_file(&config_path, &symlink_config_path).context("Failed to create symlink")?;
        }

        Ok(())
    }
}
#[derive(Debug, Serialize, Deserialize, Default)]
#[serde(default)]
struct Config {
    tracked_files: Vec<TrackedFile>,
}
impl Config {
    fn load_from_config_file() -> Result<Self> {
        let config_folder = Igor::igor_project_config().config_dir().to_path_buf();
        let config_file_path = config_folder.join("igorrc.yml");
        // try to read config file into Config struct
        let config_file =
            std::fs::File::open(config_file_path).context("Failed to open config file.")?;
        let config: Config =
            serde_yaml::from_reader(config_file).context("Failed to parse config file.")?;
        Ok(config)
    }
    // creates a new default config file
    fn new() -> Result<Self> {
        let config = Config {
            tracked_files: vec![],
        };
        Ok(config)
    }
    fn save_to_file(&self) -> Result<()> {
        let config_folder = Igor::igor_project_config().config_dir().to_path_buf();
        let config_file_path = config_folder.join("igorrc.yml");
        // try to write config file from Config struct
        let config_file =
            std::fs::File::create(config_file_path).context("Failed to create config file.")?;
        serde_yaml::to_writer(config_file, self).context("Failed to write config file.")?;
        Ok(())
    }
    fn track_file(&mut self, file_name: &Path) -> Result<()> {
        // To get the full path of the file we combine the file name with the current directory
        // stored in the Igor struct.
        let tracked_file = TrackedFile {
            path: file_name.to_path_buf(),
            name: file_name.file_name().unwrap().to_str().unwrap().to_string(),
            folder: file_name.is_dir(),
        };
        println!("{:#?}", tracked_file);
        self.tracked_files.push(tracked_file);
        self.save_to_file()?;
        // check that file exists in the filesystem
        println!("{:?}", self);
        Ok(())
    }
}

fn main() -> Result<()> {
    let mut igor = Igor::new()?;
    if igor.args.borrow_mut().show_config_path {
        // User might want to pipe this information for example to a file
        // so we must make sure that this is printed to stdout
        // https://github.com/rust-lang/rust/issues/46016
        let mut stdout = std::io::stdout();
        writeln!(stdout, "{:?}", igor.config_file)?;
    }
    if let Some(command) = &igor.args.borrow().command {
        match command {
            IgorCommands::Add { file_name } => {
                igor.config.track_file(&igor.path.join(file_name))?
            }
            IgorCommands::Init { path, name } => {
                let path = match path {
                    Some(path) => PathBuf::from(path),
                    None => {
                        PathBuf::from(UserDirs::new().context("If you see me, yell")?.home_dir())
                    }
                };
                Igor::init(&path, name)?
            }
        }
    }
    Ok(())
}

#[derive(Debug, Serialize, Deserialize)]
struct TrackedFile {
    path: PathBuf,
    name: String,
    folder: bool,
}
