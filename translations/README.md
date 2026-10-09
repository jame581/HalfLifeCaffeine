# Translating HalfLife Caffeine

Thank you for helping. You need two files for your language:

- `<lang>.csv` — the short texts shown on the watch and in the phone app
- `store-listing.<lang>.md` — the description on the Connect IQ store

## The sheet

Open `<lang>.csv` in LibreOffice or Google Sheets (File → Import), or in Excel
through **Data → From Text/CSV** (choose "65001: Unicode (UTF-8)" and comma as
the delimiter). Double-clicking the file in Excel may put everything into one
column or garble accented letters; if that happens, close without saving and
use the import route.

Fill in the `translation` column. Leave every other column as it is.

- A few texts start with `-` or `+` (such as `-15 min`). If Excel complains
  about a formula, type an apostrophe first: `'-15 min`.

- `english` is the text to translate; `context` says where it appears.
- `max` is the longest your translation may be, in characters. Watch screens
  are small and round, so shorter is better. If nothing fits, say so and we
  will find room.
- `$1$`, `$2$`, `$3$` are placeholders the app fills in (a time, a number, a
  date part). Keep each one exactly once; you may move them to wherever your
  language wants them. Example: `Sleep safe in $1$` → `$1$ jäljellä`.
- Brand names (Red Bull, Monster) stay as they are.
- If `status` says `changed`, the English text was edited after you translated
  it; please check that row again and clear the cell.

Save as **CSV UTF-8** (in Excel: "CSV UTF-8 (Comma delimited)", not plain
"CSV") and send the file back. Comma or semicolon as delimiter are both fine.

## The store listing

Translate the text under each heading in `store-listing.<lang>.md`. Keep the
headings, the emoji and the `**bold**` markers. The tagline must stay within
50 characters.

## For maintainers

`pwsh tools/build-translations.ps1` validates every sheet and regenerates
`resources*/strings.xml` and the dictionary in `companion/settings/index.html`.
Add `-Sync` after editing `en.csv`. Incomplete sheets are skipped, not built.
