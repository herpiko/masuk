use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Serialize, Deserialize, Clone)]
struct HostConfig {
    host: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    user: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    port: Option<u16>,
}

type Profiles = HashMap<String, HostConfig>;

#[derive(Debug, Serialize, Deserialize)]
struct Config {
    #[serde(default)]
    profiles: Profiles,
    updated_at: i64,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            profiles: HashMap::new(),
            updated_at: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs() as i64,
        }
    }
}

struct Masuk {
    config: Config,
    config_path: PathBuf,
}

impl Masuk {
    fn new() -> Result<Self> {
        let home = dirs::home_dir().ok_or_else(|| anyhow!("Could not determine home directory"))?;
        let config_path = home.join(".config/masuk/config.json");

        let mut masuk = Masuk {
            config: Config::default(),
            config_path,
        };

        masuk.load_config()?;
        Ok(masuk)
    }

    fn load_config(&mut self) -> Result<()> {
        // Create directory if it doesn't exist
        if let Some(parent) = self.config_path.parent() {
            fs::create_dir_all(parent)
                .context("Failed to create config directory")?;
        }

        // Try to read existing config
        match fs::read_to_string(&self.config_path) {
            Ok(data) => {
                self.config = serde_json::from_str(&data)
                    .context("Failed to parse config file")?;
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                // Create new config file
                self.save_config()?;
            }
            Err(e) => return Err(e.into()),
        }

        Ok(())
    }

    fn save_config(&mut self) -> Result<()> {
        self.config.updated_at = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        let json = serde_json::to_string_pretty(&self.config)
            .context("Failed to serialize config")?;

        fs::write(&self.config_path, json)
            .context("Failed to write config file")?;

        Ok(())
    }

    fn add(&mut self, profile: &str, host: &str, user: Option<String>, port: Option<u16>) -> Result<()> {
        // Add to config
        let host_config = HostConfig {
            host: host.to_string(),
            user,
            port,
        };

        // Build display string
        let mut display = String::new();
        if let Some(ref u) = host_config.user {
            display.push_str(&format!("{}@", u));
        }
        display.push_str(&host_config.host);
        if let Some(p) = host_config.port {
            display.push_str(&format!(":{}", p));
        }

        self.config.profiles.insert(profile.to_string(), host_config);
        self.save_config()?;

        println!("✓ Added profile '{}' → {}", profile, display);

        Ok(())
    }

    fn connect(&self, profile: &str) -> Result<()> {
        let host_config = self
            .config
            .profiles
            .get(profile)
            .ok_or_else(|| anyhow!("Profile '{}' not found. Use 'masuk ls' to see available profiles.", profile))?;

        // Build display string
        let mut display = String::new();
        if let Some(ref u) = host_config.user {
            display.push_str(&format!("{}@", u));
        }
        display.push_str(&host_config.host);
        if let Some(p) = host_config.port {
            display.push_str(&format!(":{}", p));
        }

        println!("Connecting to {} ({})...", profile, display);

        // Build SSH command
        let mut cmd = Command::new("ssh");

        // Add port if specified
        if let Some(port) = host_config.port {
            cmd.arg("-p").arg(port.to_string());
        }

        // Build the target (user@host or just host)
        let target = if let Some(ref user) = host_config.user {
            format!("{}@{}", user, host_config.host)
        } else {
            host_config.host.clone()
        };

        cmd.arg(target);

        let status = cmd.status()
            .context("Failed to execute SSH command")?;

        if !status.success() {
            return Err(anyhow!("SSH connection failed"));
        }

        Ok(())
    }

    fn list(&self) -> Result<()> {
        if self.config.profiles.is_empty() {
            println!("No profiles configured yet. Use 'masuk add <profile> -h <host>' to add one.");
            return Ok(());
        }

        println!("\nConfigured profiles:\n");
        let mut profiles: Vec<_> = self.config.profiles.iter().collect();
        profiles.sort_by_key(|(name, _)| *name);

        for (profile, host_config) in profiles {
            let mut display = String::new();
            if let Some(ref u) = host_config.user {
                display.push_str(&format!("{}@", u));
            }
            display.push_str(&host_config.host);
            if let Some(p) = host_config.port {
                display.push_str(&format!(":{}", p));
            }
            println!("  {} → {}", profile, display);
        }
        println!();
        Ok(())
    }

    fn remove(&mut self, profile: &str) -> Result<()> {
        if self.config.profiles.remove(profile).is_none() {
            return Err(anyhow!("Profile '{}' not found", profile));
        }

        self.save_config()?;
        println!("✓ Removed profile '{}'", profile);

        Ok(())
    }
}

#[derive(Parser)]
#[command(name = "masuk")]
#[command(about = "SSH host and port manager", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    #[command(about = "Add a profile with host and optional user/port. Example: 'masuk add foobar -h 192.168.1.81 -u root -p 2222'")]
    Add {
        /// Profile name
        profile: String,
        /// Host/IP address
        #[arg(short = 'h', long)]
        host: String,
        /// SSH user (optional)
        #[arg(short = 'u', long)]
        user: Option<String>,
        /// SSH port (optional, omit to use SSH default)
        #[arg(short = 'p', long)]
        port: Option<u16>,
    },
    #[command(about = "List all configured profiles")]
    #[command(alias = "ls")]
    List,
    #[command(about = "Remove a profile. Example: 'masuk remove foobar'")]
    #[command(alias = "rm")]
    Remove {
        /// Profile name
        profile: String,
    },
    #[command(external_subcommand)]
    External(Vec<String>),
}

fn main() -> Result<()> {
    // Check if we have args and if the first arg might be a profile name
    let args: Vec<String> = env::args().collect();

    // If we have exactly 2 args (program name + one arg) and it doesn't match known commands,
    // treat it as a direct connection
    if args.len() == 2 {
        let potential_profile = &args[1];
        let known_commands = ["add", "list", "ls", "remove", "rm", "help", "--help", "-h"];

        if !known_commands.contains(&potential_profile.as_str()) {
            let masuk = Masuk::new()?;
            return masuk.connect(potential_profile);
        }
    }

    let cli = Cli::parse();
    let mut masuk = Masuk::new()?;

    match cli.command {
        Commands::Add { profile, host, user, port } => {
            masuk.add(&profile, &host, user, port)?;
        }
        Commands::List => {
            masuk.list()?;
        }
        Commands::Remove { profile } => {
            masuk.remove(&profile)?;
        }
        Commands::External(args) => {
            if let Some(profile) = args.first() {
                masuk.connect(profile)?;
            } else {
                return Err(anyhow!("No profile specified"));
            }
        }
    }

    Ok(())
}
