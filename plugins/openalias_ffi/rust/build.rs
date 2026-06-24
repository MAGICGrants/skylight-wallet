// SPDX-FileCopyrightText: 2023 Foundation Devices Inc.
//
// SPDX-License-Identifier: GPL-3.0-or-later

use cbindgen::{Config, Language};
use std::env;
use std::path::PathBuf;
use glob::glob;

fn main() {
    android_on_linux_check();

    // Create C header files for Dart
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let package_name = env::var("CARGO_PKG_NAME").unwrap();

    let output_file = target_dir()
        .join(format!("{}.h", package_name))
        .display()
        .to_string();

    let config = Config {
        language: Language::C,
        ..Default::default()
    };

    cbindgen::generate_with_config(crate_dir, config)
        .unwrap()
        .write_to_file(output_file);
}

fn target_dir() -> PathBuf {
    if let Ok(target) = env::var("CARGO_TARGET_DIR") {
        PathBuf::from(target)
    } else {
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("target")
    }
}


fn android_on_linux_check() {
    let target = env::var("TARGET").unwrap();
    if target == "x86_64-linux-android" {
        let os = match env::consts::OS {
            "macos" => "darwin",
            "windows" => "windows",
            _ => "linux",
        };

        let ndk_home_result = env::var("ANDROID_NDK_HOME");
        let ndk_home = if let Some(value) = ndk_home_result.ok()  {
            value
        } else {
            println!("ANDROID_NDK_HOME not set. Trying _CARGOKIT_NDK_LINK_CLANG");
            let path_to_parse_with_hack = env::var("_CARGOKIT_NDK_LINK_CLANG")
                .expect("_CARGOKIT_NDK_LINK_CLANG not set");

            path_to_parse_with_hack
                .split("/toolchains/")
                .next()
                .expect("Failed to parse path to get NDK home")
                .to_string()
        };

        let link_search_glob = format!(
            "{}/toolchains/llvm/prebuilt/{}-x86_64/lib/clang/**/lib/linux",
            ndk_home, os
        );

        let link_search_path = glob(&link_search_glob)
            .expect("failed to read link_search_glob")
            .next()
            .expect("failed to find link_search_path")
            .expect("link_search_path glob result failed");
        println!("cargo:rustc-link-lib=static=clang_rt.builtins-x86_64-android");
        println!("cargo:rustc-link-search={}", link_search_path.display());
    }
}