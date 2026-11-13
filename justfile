# Task runner. Each recipe is a thin wrapper around a script in tools/.
# Run `just` to list recipes by group.

set shell := ["bash", "-euo", "pipefail", "-c"]

# List all recipes
default:
    @just --list --unsorted
