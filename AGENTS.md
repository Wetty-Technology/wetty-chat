## Project Overview

wetty-chat is a chat application targeting ~20k users / ~10k messages per day. It has a **Rust backend** (Axum + Diesel/PostgreSQL) and a **React frontend** (Ionic + Vite).

## SubAgents
The project is relatively large and complex, so use subagents to explore the project
unless you know for sure there are limited files to look and you know which ones.

## Planning
Before making changes always produce at least a high level overview of what you want to change. It should at least cover:
    - What is the problem
    - What is the change you want to put in at a high level
    - Is this a quick patch to get the problem resolved or the best design given our requirements

## Review
After making change, always dispatch a subagent to review and see if there are any issues

## Project Layout

### Frontend
Frontend is located in `wetty-chat-mobile` directory. It is a Progressive Web Applicaiton (PWA)
When working on frontend reference @wetty-chat-mobile/AGENTS.md

### Backend
Backend is a Rust + Axum project located in `backend` directory.
When working on backend, load @backend/AGENTS.md

### Flutter
There's also a flutter mobile app located in `wetty-chat-flutter` directory.
When working on flutter, load @wetty-chat-flutter/AGENTS.md
