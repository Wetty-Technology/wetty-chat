---
trigger: glob
globs: backend/**/*.rs
---

*** Cargo Dependency ***
When adding new dependency make sure to use the latest version by using `cargo add` do not directly add dependency to cargo.toml

*** Diesel ***
When creating migrations use `diesel migration generate` instead of manually creating a migration folder
