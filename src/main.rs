use clap::{Arg, ArgAction, Command};
use directories::ProjectDirs;
use fuzzy_matcher::skim::SkimMatcherV2;
use fuzzy_matcher::FuzzyMatcher;
use serde::{Deserialize, Serialize};
use serde_yaml;
use std::fs;
use std::io::Write;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize)]
struct Config {
    roots: Vec<String>,
    default_root: Option<String>,
    max_results: usize,
    only_directories: bool,
    root_aliases: std::collections::HashMap<String, String>,
    select_option: bool,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            roots: Vec::new(),
            default_root: None,
            max_results: 5,
            only_directories: false,
            root_aliases: std::collections::HashMap::new(),
            select_option: false,
        }
    }
}

struct App {
    name: &'static str,
    version: &'static str,
    author: &'static str,
    about: &'static str,
    company: &'static str,
}

// set information of name, version, author and about, app name
impl Default for App {
    fn default() -> Self {
        App {
            name: "easy_project_finder",
            version: "1.0",
            author: "shifat <hossain0338@gmail.com>",
            about: "Fuzzy search for project directories",
            company: "shhossain",
        }
    }
}

// Add this struct for backward compatibility
#[derive(Debug, Serialize, Deserialize)]
struct OldConfig {
    root: Option<String>,
}

fn build_cli() -> Command {
    let app = App::default();

    Command::new(app.name)
        .version(app.version)
        .author(app.author)
        .about(app.about)
        .arg(
            Arg::new("config")
                .short('c')
                .long("config")
                .value_name("KEY=VALUE")
                .help("Set configuration (root=\"path\" or root=\"alias:path\", max_results=N, only_dirs=true/false)")
                .num_args(1)
                .action(ArgAction::Append),
        )
        .arg(
            Arg::new("show-config")
                .long("show-config")
                .help("Show current configuration and its file location")
                .action(ArgAction::SetTrue),
        )
        .arg(
            Arg::new("patterns")
                .value_name("PATTERNS")
                .help("Optional root alias followed by patterns for fuzzy matching")
                .num_args(0..)
        )
        .arg(
            Arg::new("dirs-only")
                .long("dirs-only")
                .help("Only show directory matches")
                .action(ArgAction::SetTrue),
        )
}

fn get_config_path() -> PathBuf {
    let app = App::default();
    if let Some(proj_dirs) = ProjectDirs::from("com", &app.company, app.name) {
        let config_dir = proj_dirs.config_dir();
        fs::create_dir_all(config_dir).unwrap_or_else(|err| {
            eprintln!("Error creating config directory: {}", err);
            std::process::exit(1);
        });
        config_dir.join("config.yaml")
    } else {
        eprintln!("Could not determine configuration directory.");
        std::process::exit(1);
    }
}

fn load_config(config_path: &PathBuf) -> Config {
    if !config_path.exists() {
        eprintln!(
            "Config file not found at {}. Please set the root directory using --config root=\"path\"",
            config_path.display()
        );
        return Config::default();
    }

    let contents = fs::read_to_string(config_path).unwrap_or_else(|err| {
        eprintln!("Error reading config file: {}", err);
        std::process::exit(1);
    });

    // Try to parse as new config first
    match serde_yaml::from_str::<Config>(&contents) {
        Ok(config) => config,
        Err(_) => {
            // Try to parse as old config
            match serde_yaml::from_str::<OldConfig>(&contents) {
                Ok(old_config) => {
                    // Migrate old config to new format
                    let mut config = Config::default();
                    if let Some(root) = old_config.root {
                        let alias = PathBuf::from(&root)
                            .file_name()
                            .and_then(|n| n.to_str())
                            .unwrap_or("default")
                            .to_string();
                        config.root_aliases.insert(alias, root.clone());
                        config.roots.push(root.clone());
                        config.default_root = Some(root);
                    }

                    // Save the migrated config
                    save_config(config_path, &config);

                    config
                }
                Err(err) => {
                    eprintln!("Error parsing config file: {}", err);
                    std::process::exit(1);
                }
            }
        }
    }
}

fn save_config(config_path: &PathBuf, config: &Config) {
    let yaml = serde_yaml::to_string(config).unwrap_or_else(|err| {
        eprintln!("Error serializing config: {}", err);
        std::process::exit(1);
    });

    fs::write(config_path, yaml).unwrap_or_else(|err| {
        eprintln!("Error writing to config file: {}", err);
        std::process::exit(1);
    });

    println!("Configuration updated successfully.");
}

fn find_matches(pattern: &str, directory: &PathBuf, config: &Config) -> Vec<(PathBuf, i64)> {
    if !directory.exists() || !directory.is_dir() {
        return Vec::new();
    }

    let matcher = SkimMatcherV2::default();
    let mut matches: Vec<(PathBuf, i64)> = fs::read_dir(directory)
        .unwrap_or_else(|err| {
            eprintln!("Error reading directory {}: {}", directory.display(), err);
            std::process::exit(1);
        })
        .filter_map(|res| res.ok())
        .map(|entry| entry.path())
        .filter(|path| !config.only_directories || path.is_dir())
        .filter_map(|entry| {
            let name = entry.file_name()?.to_string_lossy().to_string();
            matcher
                .fuzzy_match(&name, pattern)
                .map(|score| (entry.clone(), score))
        })
        .collect();

    matches.sort_by_key(|(_, score)| -score);
    matches.truncate(config.max_results);
    matches
}

fn traverse_patterns(
    start_dir: PathBuf,
    patterns: &[String],
    config: &Config,
) -> Option<Vec<PathBuf>> {
    let mut current_dirs = vec![start_dir];
    let mut final_matches = Vec::new();

    for pattern in patterns {
        let mut next_dirs = Vec::new();
        for current_dir in current_dirs {
            let matches = find_matches(pattern, &current_dir, config);
            next_dirs.extend(matches.into_iter().map(|(path, _)| path));
        }

        if next_dirs.is_empty() {
            return None;
        }
        current_dirs = next_dirs;
    }

    if !patterns.is_empty() {
        final_matches = current_dirs;
    }

    Some(final_matches)
}

fn display_config(config: &Config, config_path: &PathBuf) {
    println!("Configuration file location: {}", config_path.display());
    println!("\nCurrent configuration:");
    println!("Root directories:");
    for root in &config.roots {
        println!("  - {}", root);
    }
    println!("\nRoot aliases:");
    for (alias, path) in &config.root_aliases {
        println!("  {}: {}", alias, path);
    }
    println!(
        "\nDefault root: {}",
        config.default_root.as_deref().unwrap_or("None")
    );
    println!("Max results: {}", config.max_results);
    println!("Only directories: {}", config.only_directories);
    println!("Select option: {}", config.select_option);
}

fn main() {
    let cli = build_cli();
    let matches = cli.get_matches();

    let config_path = get_config_path();
    let mut config = if config_path.exists() {
        load_config(&config_path)
    } else {
        Config::default()
    };

    // Show configuration if requested
    if matches.get_flag("show-config") {
        display_config(&config, &config_path);
        return;
    }

    // Handle configuration updates
    if let Some(config_args) = matches.get_many::<String>("config") {
        for arg in config_args {
            let parts: Vec<&str> = arg.splitn(2, '=').collect();
            if parts.len() != 2 {
                eprintln!("Invalid config format: {}. Use key=\"value\"", arg);
                std::process::exit(1);
            }

            let key = parts[0];
            let value = parts[1].trim_matches('"');
            let available_keys = [
                "root",
                "max_results",
                "only_dirs",
                "select_option",
                "default_root",
            ];

            match key {
                "root" => {
                    // Check if there's a colon that's not followed by / or \
                    let split_index = value
                        .chars()
                        .enumerate()
                        .find(|(i, c)| {
                            *c == ':'
                                && value
                                    .chars()
                                    .nth(i + 1)
                                    .map_or(true, |next| next != '/' && next != '\\')
                        })
                        .map(|(i, _)| i);

                    if let Some(index) = split_index {
                        let (alias, _) = value.split_at(index);
                        // Keep the original path including drive letter
                        let path = value[(index + 1)..].to_string();
                        config
                            .root_aliases
                            .insert(alias.to_string(), format!("{}:{}", alias, path));
                        config.roots.push(format!("{}:{}", alias, path));
                        if config.default_root.is_none() {
                            config.default_root = Some(format!("{}:{}", alias, path));
                        }
                    } else {
                        let path = value.to_string();
                        let alias = PathBuf::from(&path)
                            .file_name()
                            .and_then(|n| n.to_str())
                            .unwrap_or("default")
                            .to_string();
                        config.root_aliases.insert(alias, path.clone());
                        config.roots.push(path.clone());
                        if config.default_root.is_none() {
                            config.default_root = Some(path);
                        }
                    }
                }
                "default_root" => {
                    config.default_root = Some(value.to_string());
                }
                "max_results" => {
                    config.max_results = value.parse().unwrap_or(5);
                }
                "only_dirs" => {
                    config.only_directories = value.parse().unwrap_or(false);
                }
                "select_option" => {
                    config.select_option = value.parse().unwrap_or(false);
                }
                _ => {
                    eprintln!("Invalid key: {}. Available keys: {:?}", key, available_keys);
                    std::process::exit(1);
                }
            }
        }
        save_config(&config_path, &config);
        return;
    }

    // Override only_directories from command line flag
    if matches.get_flag("dirs-only") {
        config.only_directories = true;
    }

    let mut patterns: Vec<String> = matches
        .get_many::<String>("patterns")
        .unwrap_or_default()
        .cloned()
        .collect();

    // Check if the first pattern is a root alias
    let root_dir = if !patterns.is_empty() {
        if let Some(path) = config.root_aliases.get(&patterns[0]) {
            patterns.remove(0);
            PathBuf::from(path)
        } else if let Some(default_root) = &config.default_root {
            PathBuf::from(default_root)
        } else {
            eprintln!("No root directory specified and no default root configured. Use --config root=\"path\"");
            std::process::exit(1);
        }
    } else if let Some(default_root) = &config.default_root {
        PathBuf::from(default_root)
    } else {
        eprintln!("No root directory specified and no default root configured. Use --config root=\"path\"");
        std::process::exit(1);
    };

    // If no patterns provided, show the root directory
    if patterns.is_empty() {
        println!("{}", root_dir.display());
        return;
    }

    // Traverse patterns
    match traverse_patterns(root_dir, &patterns, &config) {
        Some(matches) if !matches.is_empty() => {
            let matches: Vec<_> = matches.into_iter().take(config.max_results).collect();

            // If there's only one match, output it directly
            if matches.len() == 1 {
                println!("{}", matches[0].display());
                return;
            }

            // If selection is enabled and there are multiple matches
            if config.select_option && matches.len() > 1 {
                // Show numbered list
                for (i, path) in matches.iter().enumerate() {
                    eprintln!("[{}] {}", i + 1, path.display());
                }

                // Read user input
                let mut input = String::new();
                eprint!("Select a number: ");
                std::io::stderr().flush().unwrap();
                std::io::stdin().read_line(&mut input).unwrap();

                if let Ok(selection) = input.trim().parse::<usize>() {
                    if selection > 0 && selection <= matches.len() {
                        println!("{}", matches[selection - 1].display());
                        return;
                    }
                }
                std::process::exit(1);
            } else {
                // Just output the first match if selection is disabled
                println!("{}", matches[0].display());
            }
        }
        _ => {
            eprintln!("No matches found for the provided patterns.");
            std::process::exit(1);
        }
    }
}
