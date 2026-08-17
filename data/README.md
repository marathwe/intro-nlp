# Data

This folder is for small, teaching-safe datasets that are directly
referenced from `.qmd` files on the site (e.g. a cleaned CSV students
download for an in-class exercise).

**Before adding a file here, check:**

- Is it actually needed for the published site (vs. just for your own
  prep)? If not, keep it in `IF/data/` instead.
- Do you have the right to redistribute it? For example,
  `IF/data/ESS_2018_all_kurz.dta` (European Social Survey) has
  redistribution restrictions and must **not** be copied here.
- Is it small enough to live comfortably in git (a few MB, not the
  large `.qs`/`.dta` files in `IF/data/`)?

Everything in this folder is committed to a public-ish repo by default
— when in doubt, leave the data out and instead show students how to
download/generate it themselves (e.g. the Wikipedia scraping code in
Day 1).
