# Base repo for ABI Training content

Content saved here is synchronised automatically to https://interim-training-working-group-abi.github.io/ABI-Training/ 

You must add and link it in to a hyperlink on an indexed page



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
