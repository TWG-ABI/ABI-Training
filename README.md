# MyProject Docs — Quarto Site

A Quarto website for MyProject documentation, styled with a teal colour palette.

## Prerequisites

Install Quarto: https://quarto.org/docs/get-started/

## Local development

```bash
quarto preview
```

This starts a local server at `http://localhost:4848` with live reload.

## Build

```bash
quarto render
```

Output goes to `_site/`.

## Deploy to GitHub Pages

1. In `_quarto.yml`, the `output-dir` is set to `_site`.
2. Push your repo to GitHub.
3. Go to **Settings → Pages** and set the source to **GitHub Actions**.
4. Add this file as `.github/workflows/publish.yml`:

```yaml
name: Publish to GitHub Pages
on:
  push:
    branches: [main]
jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: quarto-dev/quarto-actions/setup@v2
      - uses: quarto-dev/quarto-actions/publish@v2
        with:
          target: gh-pages
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Custom domain

Add a `CNAME` file to the repo root containing your domain (e.g. `abi-training.africa`),
then configure DNS as described in the GitHub Pages docs.

## File structure

```
.
├── _quarto.yml          # Site config, navbar, sidebar
├── styles.css           # Custom teal colour palette
├── index.qmd            # Home page
├── projects.qmd         # Projects page
├── about.qmd            # About page
└── docs/
    ├── installation.qmd
    ├── configuration.qmd
    ├── usage.qmd
    ├── advanced.qmd
    ├── api.qmd
    ├── faq.qmd
    └── contributing.qmd
```

## Adding a new doc page

1. Create a new `.qmd` file in `docs/`.
2. Add it to the `sidebar` contents list in `_quarto.yml`.
3. That's it — search indexing and TOC are automatic.
