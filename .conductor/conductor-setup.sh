#!/bin/bash
# Thin wrapper around worktree-dev.sh for Conductor compatibility
# Runs setup and exits without following logs

exec "$(dirname "$0")/../worktree-dev.sh" --setup-only
