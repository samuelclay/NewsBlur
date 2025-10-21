#!/bin/bash
# Thin wrapper around worktree-dev.sh for Conductor compatibility
# Runs setup if needed and follows logs

exec "$(dirname "$0")/../worktree-dev.sh" "$@"
