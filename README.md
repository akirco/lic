# lic

A CLI tool for initializing LICENSE files in your projects.

## Features

- Interactive license selection
- Command line arguments support
- Automatic git username detection
- Smart placeholder replacement

## Installation

```bash
cargo install --git https://github.com/akirco/lic.git
```

## Usage

```bash
# Interactive mode
lic -i

# Command line mode
lic -a "Author Name" -y "2024" -l mit # defaults to mit
```
