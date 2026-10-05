# NewsBlur interface translations

NewsBlur ships its translations with the application. Reading stories never calls a translation API. Feed content, usernames, user comments and AI-generated story content remain in their original language.

`languages.json` lists the supported BCP 47 language codes and native names. An account's `language` preference is either one of those codes or `auto`. Automatic resolves independently on each device. The web uses the browser's Accept-Language header, Android uses native resource negotiation, and iOS uses the device's preferred languages. English is the fallback. Anonymous selections are local; native login selections sync on the first successful feed refresh.

## Adding or changing text

- Web JavaScript: `gettext("Save story")`. Use `interpolate(gettext("%(name)s saved"), {name: name}, true)` for variables and `ngettext` for counts. Translate a complete sentence; never translate feed titles or concatenate translated sentence fragments.
  Keep FormData field names, DOM attribute names, CSS selectors and stored preference keys literal. They are protocol identifiers, even when they resemble English words.
- Django templates: load `i18n`, then use `trans` or `blocktrans` with named variables and `count`. Python: `gettext` or `gettext_lazy` from `django.utils.translation`.
- iOS: `NBLocalization.text("Save story")` in Swift, `[NBLocalization text:@"Save story"]` in Objective-C. New Swift files must belong to both app targets. The source scanner extracts explicit calls; never pass user content to the helper.
- Android: add strings or plurals in `res/values/strings.xml`, then use `stringResource`, `getString`, or `getQuantityString`. Stable preference values, URLs and identifiers must be `translatable="false"`. Arrays ending in `_values` are excluded.

The extractor reads all three source formats and keeps a translation memory under `translations/`. Entries are keyed by platform, context and English source text. Editing English invalidates only that message; existing translations are reused. Plurals use the target language's grammatical categories. Generated files are standard Django gettext catalogs, iOS `.strings` and `.stringsdict`, and Android resource XML. iOS plural sources live in `clients/ios/Resources/Localizable.stringsdict`; format them with `NBLocalization.plural(_:count:)` so the account override controls both wording and plural rules.

Run Python commands inside the worktree container:

```sh
docker exec -t newsblur_web_i18n /root/.local/bin/uv pip install --python /venv/bin/python -r localization/requirements.txt
docker exec -t newsblur_web_i18n python localization/manage.py extract --languages es
docker exec -t -e OPENAI_API_KEY_FILE=/path/in/container/key newsblur_web_i18n python localization/manage.py translate --provider luna --budget 5
docker exec -t newsblur_web_i18n python localization/manage.py check
docker exec -t newsblur_web_i18n python localization/manage.py compile
```

`extract` produces an optional inspectable inventory in `sources/`. `check` performs no network requests and fails on missing translations or altered placeholders/markup. `compile` regenerates the platform catalogs deterministically. Commit translation memory and generated catalogs together. Review rendered screens for wrapping, truncation, plural wording and RTL layout. Machine translation still needs native-speaker feedback for terminology and meaning.

Run `python localization/audit.py` inside the container to detect hardcoded literals in common web and native UI APIs. It checks multiline calls too, but cannot prove complete coverage: dynamic messages, custom rendering helpers and text baked into images need review. Its small exception list identifies user-data examples, never translated interface copy.

## Automatic updates

The Localization workflow checks every PR without exposing API secrets to PR code. On main pushes and a daily schedule, it translates missing strings using the existing `OPENAI_API_KEY` repository secret and opens an `automated-translations` PR. A manual workflow run also works. Translation PRs need the normal review and release process; mobile translations reach users in the next app release. A failed API request cannot replace good translations or affect the running site.

Code PRs use `check --allow-missing`: existing translations must still be valid, while new messages may merge with English fallback. The automatic update runs a strict completeness check before opening its PR. GitHub's default workflow token does not trigger other workflows from its own PR; a maintainer must trigger checks before merging an automated update, or configure a GitHub App token for that workflow.

The script reserves an upper bound before each API request and charges completed requests against the run budget using the reported token usage. Failed requests retain their reserved allowance. Completed batches are saved so a later run resumes without paying again. The default cap is $5 per invocation; it is not an account-wide billing limit. Configure provider billing limits separately if desired. Credentials are read from environment variables, a secret-file path or existing Django settings, never committed.

## Provider comparison (verified October 4, 2026)

| Provider | Standard input | Standard output | Notes |
| --- | --- | --- | --- |
| [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) | $0.10 / million tokens | $0.50 / million tokens | Default; existing CI key; strict JSON schema |
| [Gemini 2.5 Flash-Lite](https://ai.google.dev/gemini-api/docs/pricing) | $0.10 / million tokens | $0.40 / million tokens | Optional `--provider gemini`; `GEMINI_API_KEY` or `GEMINI_API_KEY_FILE` |
| [Google Cloud Translation NMT](https://cloud.google.com/products/translate/pricing) | $20 / million source characters after allowance | Included | Different billing unit |
| [Amazon Translate](https://aws.amazon.com/translate/pricing/) | $15 / million source characters | Included | Different billing unit |

Both model providers offer batch discounts. The current script uses immediate requests so translations are available in the same development run. Gemini has a slightly lower token price; Luna completed the initial Spanish messages that Gemini rejected or truncated. No translation-quality ranking is implied by price.
