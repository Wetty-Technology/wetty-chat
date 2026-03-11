---
trigger: glob
globs: backend/**/*.rs
---

*** Cargo Dependency ***

- When adding new dependency make sure to use the latest version by using `cargo add` do not directly add dependency to cargo.toml

*** Database ***

- We should use snowflake id for primary key when the order of items are important. (Most of the time)

*** Diesel ***

- When creating migrations use `diesel migration generate` instead of manually creating a migration folder
- Use diesel DSL to create query when possible. Only when absolutely nessirary use `sql_query`. DSL provide us with type safety.
