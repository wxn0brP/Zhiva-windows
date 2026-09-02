use std::sync::atomic::{AtomicUsize, Ordering};

use indicatif::{ProgressBar, ProgressStyle};

pub struct Installer {
    pb: ProgressBar,
    total: usize,
    current: AtomicUsize,
}

impl Installer {
    pub fn new(total: usize) -> Self {
        println!();
        println!("  Zhiva Installer");
        println!();

        let pb = ProgressBar::new(total as u64);
        pb.set_style(
            ProgressStyle::default_bar()
                .template("  [{bar:30}] {pos}/{len}")
                .unwrap()
                .progress_chars("=> "),
        );
        pb.set_position(0);

        Self {
            pb,
            total,
            current: AtomicUsize::new(0),
        }
    }

    pub fn step(&self, name: &str) {
        let idx = self.current.fetch_add(1, Ordering::SeqCst) + 1;
        let label = format!("[{}/{}] {}", idx, self.total, name);
        self.pb.set_message(label);
    }

    pub fn done(&self, msg: &str) {
        self.pb.inc(1);
        self.pb.set_message(msg.to_string());
    }

    pub fn finish(&self) {
        self.pb.finish_with_message("done");
        println!();
        println!("  All done! You can now use Zhiva from any terminal.");
        println!();
    }

    pub fn fail(&self, err: &anyhow::Error) {
        self.pb.abandon_with_message("failed");
        println!();
        eprintln!("  Error: {err:#}");
        println!();
    }
}
