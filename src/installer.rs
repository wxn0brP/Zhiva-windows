use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Context, Result};
use winreg::enums::*;
use winreg::types::RegValue;
use winreg::RegKey;

use crate::ui::Installer;

fn home_dir() -> Result<PathBuf> {
    dirs()
        .or_else(|| std::env::var("USERPROFILE").ok().map(PathBuf::from))
        .context("Cannot determine home directory")
}

fn dirs() -> Option<PathBuf> {
    std::env::var("USERPROFILE")
        .ok()
        .map(PathBuf::from)
        .filter(|p| p.exists())
}

fn zhiva_dir() -> Result<PathBuf> {
    Ok(home_dir()?.join(".zhiva"))
}

fn zhiva_bin() -> Result<PathBuf> {
    Ok(zhiva_dir()?.join("bin"))
}

fn command_exists(cmd: &str) -> bool {
    Command::new("where.exe")
        .arg(cmd)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn run_cmd(program: &str, args: &[&str]) -> Result<()> {
    run_cmd_in(program, args, None)
}

fn run_cmd_in(program: &str, args: &[&str], dir: Option<&Path>) -> Result<()> {
    let mut cmd = Command::new(program);
    cmd.args(args);
    if let Some(d) = dir {
        cmd.current_dir(d);
    }
    let status = cmd
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .status()
        .context(format!("Failed to run {program}"))?;

    if !status.success() {
        bail!("{program} exited with status {status}");
    }
    Ok(())
}

fn download_bytes(url: &str) -> Result<Vec<u8>> {
    let resp = reqwest::blocking::get(url)
        .context(format!("Failed to download {url}"))?
        .error_for_status()
        .context(format!("HTTP error downloading {url}"))?;
    Ok(resp
        .bytes()
        .context("Failed to read response bytes")?
        .to_vec())
}

fn download_to_file(url: &str, dest: &Path) -> Result<()> {
    let bytes = download_bytes(url)?;
    fs::write(dest, &bytes).context(format!("Failed to write {}", dest.display()))?;
    Ok(())
}

fn download_json(url: &str) -> Result<serde_json::Value> {
    let resp = reqwest::blocking::get(url)
        .context(format!("Failed to fetch {url}"))?
        .error_for_status()
        .context(format!("HTTP error fetching {url}"))?;
    let text = resp.text().context("Failed to read response text")?;
    serde_json::from_str(&text).context("Failed to parse JSON")
}

// --- Step 1: Git ---

fn install_git(ui: &Installer) -> Result<()> {
    if command_exists("git") {
        ui.done("Git already installed");
        return Ok(());
    }

    ui.step("Installing Git");

    let release: serde_json::Value =
        download_json("https://api.github.com/repos/git-for-windows/git/releases/latest")?;

    let asset = release["assets"]
        .as_array()
        .context("No assets in release")?
        .iter()
        .find(|a| {
            a["name"]
                .as_str()
                .map(|n| n.ends_with("64-bit.exe"))
                .unwrap_or(false)
        })
        .context("Git 64-bit installer not found in latest release")?;

    let download_url = asset["browser_download_url"]
        .as_str()
        .context("No download URL for Git installer")?;

    let installer_path =
        std::env::temp_dir().join(asset["name"].as_str().unwrap_or("git-installer.exe"));

    download_to_file(download_url, &installer_path)?;

    run_cmd(
        &installer_path.to_string_lossy(),
        &["/VERYSILENT", "/NORESTART"],
    )?;

    let _ = fs::remove_file(&installer_path);

    ui.done("Git installed");
    Ok(())
}

// --- Step 2: Bun ---

fn install_bun(ui: &Installer) -> Result<()> {
    if command_exists("bun") {
        ui.done("Bun already installed");
        return Ok(());
    }

    ui.step("Installing Bun");

    let bun_root = std::env::var("BUN_INSTALL")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().unwrap().join(".bun"));
    let bun_bin = bun_root.join("bin");
    fs::create_dir_all(&bun_bin)?;

    // Try official installer first
    let mut installed = false;
    let ps_result = Command::new("powershell")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "irm https://bun.sh/install.ps1 | iex",
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status();

    if let Ok(status) = ps_result {
        if status.success() && command_exists("bun") {
            installed = true;
        }
    }

    // Fallback: manual install
    if !installed {
        let zip_path = bun_bin.join("bun.zip");
        download_to_file(
            "https://github.com/oven-sh/bun/releases/latest/download/bun-windows-x64.zip",
            &zip_path,
        )?;

        let zip_file = fs::File::open(&zip_path)?;
        let mut archive = zip::ZipArchive::new(zip_file)?;
        archive.extract(&bun_bin)?;

        let extracted = bun_bin.join("bun-windows-x64");
        if extracted.join("bun.exe").exists() {
            fs::copy(extracted.join("bun.exe"), bun_bin.join("bun.exe"))?;
            let _ = fs::remove_dir_all(&extracted);
        }
        let _ = fs::remove_file(&zip_path);

        // Add to PATH if not already there
        if !command_exists("bun") {
            add_to_user_path(&bun_bin)?;
            // Also update current process PATH so bun is found immediately
            let current = std::env::var("PATH").unwrap_or_default();
            std::env::set_var("PATH", format!("{current};{}", bun_bin.to_string_lossy()));
        }

        if !bun_bin.join("bun.exe").exists() {
            bail!("Bun installation failed - bun.exe not found");
        }
    }

    ui.done("Bun installed");
    Ok(())
}

// --- Step 3: Zhiva base setup ---

fn setup_zhiva(ui: &Installer, app_name: &str) -> Result<()> {
    ui.step("Setting up Zhiva");

    let dir = zhiva_dir()?;
    let bin = zhiva_bin()?;
    let scripts = dir.join("scripts");

    fs::create_dir_all(&bin)?;

    // Clone or pull zhiva-scripts
    if !scripts.join(".git").exists() {
        run_cmd(
            "git",
            &[
                "clone",
                "https://github.com/wxn0brP/Zhiva-scripts.git",
                &scripts.to_string_lossy(),
            ],
        )?;
    } else {
        run_cmd("git", &["-C", &scripts.to_string_lossy(), "pull"])?;
    }

    // Copy package.json and install deps
    let pkg_src = scripts.join("package.json");
    let pkg_dst = dir.join("package.json");
    if pkg_src.exists() {
        fs::copy(&pkg_src, &pkg_dst)?;
    }

    run_cmd_in("bun", &["install", "--production", "--force"], Some(&dir))?;

    // Bootstrap CLI
    run_cmd_in("bun", &["run", "scripts/src/cli.ts", "self"], Some(&dir))?;

    // Create zhiva.cmd
    let cmd_content = format!(
        r#"@echo off

if defined _ZHIVA_BG_RUN (
    bun run "%USERPROFILE%\.zhiva\scripts\src\cli.ts" %*
    exit /b
)

if defined _ZHIVA_BG (
    set _ZHIVA_BG_RUN=1
    start "" /min cmd /c "%~f0" %*
    exit /b
)

bun run "%USERPROFILE%\.zhiva\scripts\src\cli.ts" %*
"#,
    );
    fs::write(bin.join("zhiva.cmd"), cmd_content)?;

    ui.done("Zhiva ready");
    Ok(())
}

// --- Step 4: PATH ---

fn get_user_path() -> Result<String> {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let env_key = hkcu.open_subkey_with_flags("Environment", KEY_READ | KEY_WRITE)?;
    let val: String = env_key.get_value("PATH").unwrap_or_default();
    Ok(val)
}

fn set_user_path(value: &str) -> Result<()> {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let env_key = hkcu.open_subkey_with_flags("Environment", KEY_READ | KEY_WRITE)?;

    let kind = if value.contains('%') {
        REG_EXPAND_SZ
    } else {
        REG_SZ
    };

    let reg_val = RegValue {
        vtype: kind,
        bytes: value.encode_utf16().flat_map(|c| c.to_le_bytes()).collect(),
    };
    env_key.set_raw_value("PATH", &reg_val)?;

    broadcast_env_change();

    Ok(())
}

fn broadcast_env_change() {
    use std::ffi::CString;
    use std::os::windows::raw::HANDLE;

    extern "system" {
        fn SendMessageTimeoutA(
            hwnd: HANDLE,
            msg: u32,
            wparam: usize,
            lparam: *const i8,
            flags: u32,
            timeout: u32,
            result: *mut usize,
        ) -> HANDLE;
    }

    const HWND_BROADCAST: HANDLE = 0xffff as HANDLE;
    const WM_SETTINGCHANGE: u32 = 0x001A;
    const SMTO_ABORTIFHUNG: u32 = 0x0002;

    let msg = CString::new("Environment").unwrap();
    let mut result: usize = 0;
    unsafe {
        SendMessageTimeoutA(
            HWND_BROADCAST,
            WM_SETTINGCHANGE,
            0,
            msg.as_ptr(),
            SMTO_ABORTIFHUNG,
            5000,
            &mut result,
        );
    }
}

fn add_to_user_path(new_path: &Path) -> Result<()> {
    let current = get_user_path()?;
    let normalized = new_path
        .to_string_lossy()
        .trim_end_matches('\\')
        .to_string();

    // Check if already in PATH
    for entry in current.split(';') {
        if entry
            .trim_end_matches('\\')
            .eq_ignore_ascii_case(&normalized)
        {
            return Ok(());
        }
    }

    let new_value = if current.is_empty() {
        normalized
    } else {
        format!("{current};{normalized}")
    };

    set_user_path(&new_value)?;
    Ok(())
}

fn add_zhiva_to_path(ui: &Installer) -> Result<()> {
    ui.step("Configuring PATH");

    let bin = zhiva_bin()?;
    add_to_user_path(&bin)?;

    ui.done("PATH updated");
    Ok(())
}

// --- Step 5: Protocol ---

fn register_protocol(ui: &Installer) -> Result<()> {
    ui.step("Registering protocol");

    let bin = zhiva_bin()?.join("zhiva.cmd");
    let cmd = format!("\"{}\" protocol \"%1\"", bin.to_string_lossy());

    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let classes = hkcu.open_subkey_with_flags("Software\\Classes", KEY_READ | KEY_WRITE)?;

    let proto = classes.create_subkey("zhiva")?;
    proto.0.set_value("URL Protocol", "")?;

    let shell_cmd = proto.0.create_subkey("shell\\open\\command")?;
    shell_cmd.0.set_value("", &cmd)?;

    ui.done("Protocol registered");
    Ok(())
}

// --- Finalize ---

fn finalize(ui: &Installer, app_name: &str) -> Result<()> {
    ui.step("Finishing up");

    let bin = zhiva_bin()?.join("zhiva.cmd");
    let bin_str = bin.to_string_lossy();

    // Run zhiva self
    let _ = Command::new(&*bin_str)
        .arg("self")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status();

    // Run zhiva install <app>
    let _ = Command::new(&*bin_str)
        .args(["install", app_name])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status();

    ui.done("Complete");
    Ok(())
}

// --- Public API ---

pub fn run(app_name: &str) -> Result<()> {
    let ui = Installer::new(5);

    install_git(&ui).and_then(|_| install_bun(&ui))?;
    setup_zhiva(&ui, app_name)?;
    add_zhiva_to_path(&ui)?;
    register_protocol(&ui)?;
    finalize(&ui, app_name)?;

    ui.finish();
    Ok(())
}
