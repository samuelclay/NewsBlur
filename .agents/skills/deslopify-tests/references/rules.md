# Test rules for NewsBlur's agent guidance

Ansh Nanda's three rules, adapted to sit beside NewsBlur's Bug Fixing Workflow, which already asks for a failing test before a fix. Ansh says "never write unit tests after you write code". Here that becomes rule 2.

1. **Name the bug first.** Before writing a test, write down the rule it protects and a realistic change that would break it. If the only way to break it is to edit the literal the test repeats, don't write it.
2. **Write the failure list before the code.** For a bug report, the reproducing test comes first and must fail before the fix. For new code, list the ways it can fail before writing it, then test that list. Don't write tests afterwards by reading the finished code.
3. **Test at the highest level that can see the behavior.** Extend an existing view or task test (the Django test client, a model method called the way a view calls it) before adding a test of a private helper.
4. **Don't write** constant or prompt mirrors, mock echo, tests of one-line wrappers, presentation checks, or snapshots with no behavior contract.
5. **Don't turn red tests green by deleting, skipping, or weakening them.** Deleting a test is a separate change that needs proof: break the code and show the test still passes or that another test catches the same bug.

## How to merge

- The rules go in the "Tests" list under "Code Style" in `AGENTS.md` (`CLAUDE.md` is a symlink to it), next to the `Test_` and `test_` naming rules.
- For each rule, check whether the file already says it. Same meaning in different words counts as present; the Bug Fixing Workflow already covers the first half of rule 2. Add only what is missing, one clause each, in the file's own voice.
- Don't restate a rule in a second place, and don't add worked examples.
- Keep the pointer to this skill: "To delete tests that fail these rules, use the `deslopify-tests` skill."
