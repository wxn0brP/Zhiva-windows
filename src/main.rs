mod installer;
mod ui;

const APP_NAME: &str = env!("ZHIVA_APP_NAME");

fn main() {
    if let Err(e) = installer::run(APP_NAME) {
        eprintln!("  Installation failed: {e:#}");
        std::process::exit(1);
    }
}
