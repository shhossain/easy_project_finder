# Easy Project Finder

`easy_project_finder` is a command-line tool for quickly locating project directories using fuzzy search. It is designed to help developers and teams manage and navigate large codebases or folder structures efficiently.

## Features

- **Fuzzy Search**: Locate directories or files using partial matches.
- **Configuration**: Customize search roots, maximum results, directory-only filtering, and more.
- **Aliases**: Assign aliases to root directories for quicker access.
- **Automatic Navigation**: Automatically change to the found directory.
- **User-Friendly CLI**: Intuitive command-line options for configuration and usage.

## Installation

To install `easy_project_finder` on Windows, run the following PowerShell command:

```powershell
iwr -useb https://raw.githubusercontent.com/shhossain/easy_project_finder/main/installer.ps1 | iex
```

This command will:

1. Download the latest release of `easy_project_finder` from GitHub.
2. Install the executable to `C:\Program Files\easy_project_finder`.
3. Add the installation directory to your system's PATH for easy access.
4. Set up a PowerShell function (`p`) for quick access and navigation to projects.

## Usage

After installation, use the `p` function to search for projects by partial names:

```powershell
p <pattern>
```

Example:

```powershell
p my_project
```

This command will search for directories matching "my_project" and, if found, automatically change to the directory.

## CLI Options

Here’s a summary of some useful command-line options:

- `--config <KEY=VALUE>`: Set configuration options like `root`, `max_results`, `only_dirs`.
  - Example: `p --config root="C:\Projects"`
- `--show-config`: Display the current configuration and its file location.
- `--dirs-only`: Filter results to only directories.
- `--help`: Show help information.

## Configuration

Configuration options can be set with the `--config` flag. Example configuration keys:

- **root**: Set the main search root or alias paths for project directories.
- **max_results**: Define the maximum number of results to display (default: 5).
- **only_dirs**: Set to `true` to only return directory results.
- **select_option**: Enable a numbered list for multiple matches, allowing manual selection.

To view your configuration, use:

```powershell
p --show-config
```

## Example Commands

1. **Set Configuration**:

   ```powershell
   p --config root="C:\Code\MyProjects"
   ```

2. **Show Configuration**:

   ```powershell
   p --show-config
   ```

3. **Directory-Only Search**:

   ```powershell
   p --dirs-only <pattern>
   ```

4. **Search with Root Alias**:
   ```powershell
   p my_alias <pattern>
   ```

## Updating Configuration

Your configuration is stored in a `config.yaml` file in the system's configuration directory. You can edit this file directly or use `--config` commands for updates.

## Troubleshooting

If you encounter issues, ensure that:

- The `installer.ps1` script ran successfully.
- `easy_project_finder.exe` is in `C:\Program Files\easy_project_finder`.
- `PATH` includes `C:\Program Files\easy_project_finder`.
