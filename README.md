# Clusterstrike Crew MekHQ Sync Guide

This repository is used by the Clusterstrike Crew (by buds) to keep MekHQ build, saves, and custom data synchronized.

## What This Repo Is For

- Sharing one campaign state across the group
- Keeping custom data in sync
- Avoiding accidental overwrites by using Git history

## Tool to Use

Use GitHub Desktop: https://desktop.github.com/download/

## First-Time Setup (GitHub Desktop)

1. Install and open GitHub Desktop.
2. Sign in with your GitHub account.
3. Clone this repository to your computer.
4. Open the cloned folder and make sure MekHQ runs from it.

## Standard Workflow (Every Time You Edit the Campaign)

Follow this order exactly to reduce merge conflicts:

1. In GitHub Desktop, select this repository.
2. Click **Fetch origin** (or **Pull origin** if shown) to get the latest changes.
3. Open MekHQ and load the campaign save.
4. Make your changes in MekHQ.
5. Save your changes over the same campaign files.
6. Return to GitHub Desktop and review changed files.
7. Enter a clear commit message describing what you changed.
8. Click **Commit to main** (or the current branch name).
9. Click **Push origin** to upload your commit.

## Pull and Push in GitHub Desktop (Quick Reference)

- **Pull latest changes**
  1. Open the repo in GitHub Desktop.
  2. Click **Fetch origin**.
  3. If updates are available, click **Pull origin**.

- **Push your changes**
  1. Commit your local changes first.
  2. Click **Push origin**.

## Commit Message Examples

- `Updated contracts and advanced one week`
- `Added pilot skill changes after mission`
- `Fixed campaign settings and saved new roster`

## Important Rules

- Always pull before opening/saving the campaign.
- Always commit and push immediately after finishing your session.
- If GitHub Desktop shows a conflict, stop and ask in the group before continuing.