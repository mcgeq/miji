// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           files.rs
// Description:    About Files and Directories
// Create   Date:  2025-05-30 13:50:30
// Last Modified:  2025-05-30 14:21:53
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::{
    env, io,
    path::{Path, PathBuf},
};

pub struct MijiFiles;

impl MijiFiles {
    pub fn root_path() -> io::Result<String> {
        let mut root_dir = PathBuf::new();
        if let Ok(exe_path) = env::current_exe() {
            root_dir.push(exe_path);
        } else {
            root_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        }
        if root_dir.exists() {
            if let Some(p) = root_dir.parent() {
                Ok(p.to_string_lossy().into_owned())
            } else {
                Err(io::Error::new(io::ErrorKind::NotFound, "Path not found"))
            }
        } else {
            Err(io::Error::new(io::ErrorKind::NotFound, "Path not found"))
        }
    }

    pub fn join(paths: &[&str]) -> PathBuf {
        let mut path = PathBuf::new();
        for p in paths {
            path.push(p);
        }
        path
    }

    pub fn exists(dir: &Path) -> bool {
        dir.exists()
    }
}
