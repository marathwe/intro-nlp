# Data

This folder is for small, teaching-safe datasets that are directly
referenced from `.qmd` files on the site (e.g. a cleaned CSV students
download for an in-class exercise).

**Before adding a file here, check:**

- Is it actually needed for the published site (vs. just for your own
  prep)? If not, keep it in `../IF/data/` instead.
- Do you have the right to redistribute it? For example,
  `../IF/data/ESS_2018_all_kurz.dta` (European Social Survey) has
  redistribution restrictions and must **not** be copied here.
- Is it small enough to live comfortably in git (a few MB, not the
  large `.qs`/`.dta` files in `../IF/data/`)?

Everything in this folder is committed to a public-ish repo by default
— when in doubt, leave the data out and instead show students how to
download/generate it themselves (e.g. the Wikipedia scraping code in
Day 1).

## Currently included

- `wikipedia_nobel_biographies_summaries_clean.qs` — 1,006 rows;
  `title`, `pageid`, `extract`, `revision`, `gender`. Used throughout
  Day 1 (`clean_text_data`).
- `wikipedia_nobel_biographies_summaries_extended_clean.qs` — 1,047
  rows; adds `Year` and `category`. Used in Day 1's optional task and
  Day 2's classification exercises.

Both are declared under `project: resources:` in `_quarto.yml` so
Quarto copies them into `_site/data/` on every render/publish, and
linked as download buttons from `notes/day1.qmd`.
