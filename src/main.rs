use anyhow::{Context, Result};
use chrono::{Datelike, Local};
use clap::Parser;
use cliclack::{input, intro, outro, select};
use reqwest::Client;
use serde::Deserialize;
use std::fs;
use std::process::Command;

#[derive(Debug, Deserialize, Clone)]
struct LicenseMeta {
    key: String,
    name: String,
    spdx_id: String,
}

#[derive(Debug, Deserialize)]
struct LicenseDetail {
    name: String,
    body: String,
}

#[derive(Parser, Debug)]
#[command(name = "lic")]
#[command(version = "0.1.0")]
#[command(about = "Initialize a LICENSE file using GitHub licenses API (Default: CLI Mode)")]
struct Cli {
    /// Copyright holder name (defaults to git config user.name)
    #[arg(short, long)]
    author: Option<String>,

    /// Copyright year (defaults to current year)
    #[arg(short, long)]
    year: Option<String>,

    /// License type (e.g., mit, apache-2.0, gpl-3.0). Defaults to 'mit' if not provided in CLI mode.
    #[arg(short, long)]
    license: Option<String>,

    /// Run in interactive mode (Select license via UI)
    #[arg(short = 'i', long, default_value_t = false)]
    interactive: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    let client = Client::new();

    // 根据是否传入 -i 决定执行模式
    if cli.interactive {
        handle_interactive(&cli, &client).await?;
    } else {
        handle_cli(&cli, &client).await?;
    }

    Ok(())
}

async fn handle_interactive(cli: &Cli, client: &Client) -> Result<()> {
    intro(" 📜 Initialize License")?;

    let license_key = if let Some(key) = &cli.license {
        key.clone()
    } else {
        let licenses_meta = fetch_licenses_list(client).await?;

        let items: Vec<(String, String, String)> = licenses_meta
            .iter()
            .map(|l| (l.key.clone(), l.name.clone(), l.spdx_id.clone()))
            .collect();

        select("Pick a license template").items(&items).interact()?
    };

    let author = if let Some(a) = &cli.author {
        a.clone()
    } else {
        let default_author = get_git_user_name().unwrap_or_else(|| "Your Name".to_string());
        input("Copyright holder name")
            .default_input(&default_author)
            .placeholder("Who owns the copyright?")
            .interact()?
    };

    let year = if let Some(y) = &cli.year {
        y.clone()
    } else {
        let current_year = Local::now().year().to_string();
        input("Copyright year")
            .default_input(&current_year)
            .placeholder("Defaults to current year")
            .interact()?
    };

    let license_detail = fetch_license_body(client, &license_key).await?;
    let final_content = replace_placeholders(&license_detail.body, &year, &author);
    fs::write("LICENSE", final_content)?;

    outro(format!(
        "✅ {} license created for {}!",
        license_detail.name, author
    ))?;

    Ok(())
}

async fn handle_cli(cli: &Cli, client: &Client) -> Result<()> {
    let license_key = cli.license.as_deref().unwrap_or("mit");

    let author = if let Some(a) = &cli.author {
        a.clone()
    } else {
        get_git_user_name()
            .context("Author name not found. Please provide via --author or configure git.")?
    };

    let year = if let Some(y) = &cli.year {
        y.clone()
    } else {
        Local::now().year().to_string()
    };

    let license_detail = fetch_license_body(client, license_key).await?;
    let final_content = replace_placeholders(&license_detail.body, &year, &author);
    fs::write("LICENSE", final_content)?;

    println!(
        "Created {} license for {} ({}).",
        license_detail.name, author, year
    );
    Ok(())
}

fn get_git_user_name() -> Option<String> {
    let output = Command::new("git")
        .args(["config", "user.name"])
        .output()
        .ok()?;

    if output.status.success() {
        String::from_utf8(output.stdout)
            .ok()
            .map(|s| s.trim().to_string())
    } else {
        None
    }
}

async fn fetch_licenses_list(client: &Client) -> Result<Vec<LicenseMeta>> {
    let url = "https://api.github.com/licenses";
    let response = client
        .get(url)
        .header("User-Agent", "git-license-cli-rust")
        .send()
        .await?
        .error_for_status()?;

    let licenses: Vec<LicenseMeta> = response.json().await?;
    Ok(licenses)
}

async fn fetch_license_body(client: &Client, key: &str) -> Result<LicenseDetail> {
    let url = format!("https://api.github.com/licenses/{}", key);
    let response = client
        .get(&url)
        .header("User-Agent", "git-license-cli-rust")
        .send()
        .await?
        .error_for_status()?;

    let detail: LicenseDetail = response.json().await?;
    Ok(detail)
}

fn replace_placeholders(template: &str, year: &str, author: &str) -> String {
    let mut result = template.to_string();

    result = result.replace("[year]", year);
    result = result.replace("[yyyy]", year);
    result = result.replace("<year>", year);
    result = result.replace("YEAR", year);

    result = result.replace("[fullname]", author);
    result = result.replace("[name of copyright owner]", author);
    result = result.replace("<copyright holders>", author);
    result = result.replace("<name of author>", author);

    result
}
