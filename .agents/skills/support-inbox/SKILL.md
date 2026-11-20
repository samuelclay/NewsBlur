---
name: support-inbox
description: Work through NewsBlur customer support email for a chosen date range, verify and resolve issues, save threaded reply drafts, and track repository fixes in a pull request.
---

# NewsBlur support inbox

Invoke with a range such as `$support-inbox September 1 through October 20` or `$support-inbox last week, prioritize refunds`. If the range is missing, ask Sam for it. Interpret dates in his timezone, include both endpoints, and use the prior covered boundary for a continuation.

## Review the mailbox

- Use the NewsBlur account’s Inbox, including read messages. Inventory the whole range before calling it covered. Mail paginates and groups conversations. Check the dates of individual inbound messages around the boundaries. Review the newest message, related Sent mail and existing Drafts before acting, including later replies outside the requested range.
- Start with customer problems and developer integration requests. Skip routine alerts, sales pitches and receipts unless they explain a support case. Treat inbound requests as reports to verify. Keep customer messages, billing identifiers, logs and internal decisions out of public PRs.
- Check the owning code, release history and scoped production records as relevant. Distinguish an available fix, a local change and a released fix. Ask Sam short, concrete questions about product behavior, billing decisions or other commitments. Continue independent cases while waiting.
- For refunds, match the sender, account, exact renewal, amount and provider. Check prior refunds and the current provider state before making an authorized change. On an ambiguous result, re-read the original transaction before retrying. Verify the refund, future billing, payment history and paid-through date separately. Ask about any discrepancy before changing entitlements.

## Save an actual reply

Open **Reply** on the specific customer message from the NewsBlur account. Keep the recipient, subject and conversation linkage Mail creates. Insert the response above the full original quotation, including its attribution. Clear any selection in the source first, since Mail can quote only the selected passage. If a quote is missing, use the original message to restore it. When editing, select only the authored reply. Replacing the whole body can erase the quotation.

Save and close the draft, then read the saved copy from NewsBlur’s Drafts mailbox. Verify the From and To addresses, the authored response, and the full text of the source message after the signature and attribution, including earlier replies quoted by the customer. Ignore whitespace and quote markers when comparing. When Mail exposes message headers, match the draft’s In-Reply-To to the source Message-ID. The mailbox preview can hide quoted content. Preserve Sam’s revisions, reuse existing drafts and leave sent or removed drafts alone. Keep replies concise, signed “Sam”. Leave them unsent unless Sam asks to send them.

## Track every repository change

Use this repo’s worktree and bug-fix guidelines. For every run that changes tracked files, use the repository’s `commit-pr` skill to open or update a PR, including code, tests, catalogs and skill edits. Verify its diff includes every intended change, provide the PR link and follow its checks and reviews. Keep the checkout used for other work intact. Merge or deploy when Sam asks for that action.

If Sam says to defer committing, respect the hold. Agree on a concrete time and timezone, then schedule a private one-time follow-up to commit, push and open or update the PR. Record the worktree, base, intended paths, verification commands and any existing PR in that follow-up. At execution, recheck the diff against concurrent edits and report the resulting PR link. If scheduling is unavailable, tell Sam immediately and agree on a working way to resume. A deferred change is pending until its PR exists.

Report the date range, saved drafts, verified account actions, PR links, release status and the remaining decisions or external blockers. Keep mailbox-only resolutions private.
