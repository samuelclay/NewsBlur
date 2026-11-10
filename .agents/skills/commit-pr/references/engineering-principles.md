# Keep the change lean

Aim for the smallest clear, correct change within what was asked. Adapted from the Tavus skillshare `commit-pr` skill.

- Extend existing modules, test files, and fixtures when they fit. Add a file or an abstraction only when it makes the code clearer; moving bulk around is not simplification.
- Keep one-off replay scripts, experiments, and handoff notes out of the PR unless someone will maintain them. Scratch work stays in the worktree or a scratch directory, never a new top-level folder.
- Test behavior through public entry points (views, model methods, tasks), mock at I/O boundaries (network, proxies, mail, payments), and reuse existing fixtures. Trim redundant cases and setup. Keep coverage for privacy, authorization, premium-tier gating, retries, and failure fallbacks.
- No unused settings, speculative options, compatibility wrappers, or experiment-only logging. Keep the signals needed to diagnose a production failure.
- Merge duplicate validation only when it is safe. Checks at different trust or timing boundaries may both be needed, such as validating a URL when a feed is added and again before it is fetched.
- Keep comments few: durable intent and invariants only, with the file name where CLAUDE.md asks for it. No agent narration, no account of how the patch was reached, no forum topic, PR, or issue numbers in code comments. That traceability goes in the commit message and the PR body.

Before committing, read the whole diff once for code, setup, and files that can come out. Optimize what has to be maintained, not line counts.
