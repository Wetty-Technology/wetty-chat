# Repository Guidelines

## Project Structure & Module Organization

This repository contains three apps plus shared docs and API collections. `backend/` is the Rust API server; core modules live in `src/handlers`, `src/services`, `src/utils`, and `src/schema`, with Diesel migrations in `migrations/`.

## Design background

- The application is designed to handle 20K users, and 200k messages a year (combined across all users).
- Expect around 5K users in a large chat group.

## API Serialization
- All API should use camel case for field naming
- use `#[serde(rename_all="camelCase")]

## Database & Index

- When making changes related to the database, be extra careful and review all queries using table / index you are changing.
- When designing new table / column / queries, make sure to also consider if it needs a corressponding index.
- Pay extra attention if you are modifying queries related to messages, thread, reactions. These are high volumn tables, and have huge performance impact.
- On these high volume / large table, if after modification we have index no longer in use, be sure to highlight that and ask the user if we can drop those index.
- When introducing a query, think about **Is this the most efficient way to query this?** before proceeding.

## Build, Test, and Development Commands

Run backend work from `backend/`:

- `cargo run` starts the API on `http://localhost:3000`.
- `cargo build` verifies the Rust backend compiles.
- `cargo clippy` checks lint issues before review.
- `diesel migration run` applies local PostgreSQL migrations.

## Coding Style & Naming Conventions

Rust uses edition 2021 and strict lints: `unsafe_code` is forbidden and `unused_must_use` is denied. Use `cargo fmt`, `snake_case` for modules/functions, and `PascalCase` for types.
Keep Axum handlers grouped by feature, and move database logic into services or models.

## Database Related

- Use diesel DSL when ever possible, only fall back to raw SQL query when absolutely required
- Never manually create migration, new migration should always be generated via `diesel migration generate`
- When writing queries make sure to verify that we do not trigger a table scan of too many rows
