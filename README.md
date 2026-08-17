# Introduction to NLP — Summer School Website

Quarto website for the "Introduction to NLP" course (Informatica
Feminale Summer School). Built with [Quarto](https://quarto.org/).

## Structure

```
.
├── IF/                  # last year's raw material — archive, gitignored, never published
├── index.qmd            # home page
├── schedule.qmd          # day-by-day schedule
├── slides/               # revealjs slide decks (day1.qmd, day2.qmd, day3.qmd)
├── notes/                # prose lecture notes matching the slides
├── assignments/          # credit-point assignment description
├── resources.qmd         # literature & R package references
├── images/                # diagrams used across slides/notes
├── styles/                # site.scss (website) and slides.scss (revealjs) themes
├── data/                  # small, redistribution-safe datasets only (see data/README.md)
└── .github/workflows/     # GitHub Actions: render + publish to GitHub Pages
```

Most `slides/*.qmd` and `notes/*.qmd` files currently contain `<!-- TODO -->`
placeholders pointing at the exact lines in `IF/scripts/all_notes.Rmd` and
`IF/slides/*.Rmd` to port over — treat them as a checklist.

## Local setup

```sh
brew install --cask quarto   # if not already installed
quarto preview                # live-reload local preview
quarto render                 # build the static site into _site/
```

R packages needed to render the code chunks: `tidyverse`, `quanteda`,
`quanteda.textmodels`, `quanteda.textstats`, `quanteda.textplots`,
`WikipediR`, `wikkitidy`, `httr2`, `rollama`.

## Publishing

A GitHub Actions workflow (`.github/workflows/publish.yml`) renders the
site and pushes it to a `gh-pages` branch on every push to `main`. To
activate it:

1. Push this repo to GitHub.
2. In **Settings → Actions → General**, allow the default `GITHUB_TOKEN`
   read/write permissions.
3. After the first workflow run creates the `gh-pages` branch, go to
   **Settings → Pages** and set the source to the `gh-pages` branch.
4. If the repo is private, GitHub Pages requires a paid plan — otherwise
   make the repo public once the content is ready.

## Data & privacy

`IF/` is gitignored on purpose: it holds personal documents
(`IF/orga/`) and datasets with redistribution restrictions
(`IF/data/ESS_2018_all_kurz.dta`). Only copy specific, cleared files out
of `IF/` into `images/`, `data/`, or content pages as needed — see
`data/README.md`.
