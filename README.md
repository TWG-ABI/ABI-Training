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

## What is this repo for?
ABI Bioinformatics Summer School 2026
Course overview/description: The African Bioinformatics Institute will be hosting a Summer School from 08 - 19 June 2026 at the African Center of Excellence in Bioinformatics and Data Intensive Sciences (ACE-Uganda), in partnership with the Uganda Virus Research Institute (UVRI), and the MRC/UVRI & LSHTM Uganda Research Unit. The aim is to provide comprehensive training on bioinformatics computational resources, and domain-specific tools and workflows to improve participants' proficiency in executing, interpreting, and communicating analyses for major bioinformatics studies, with a special focus on genomics.

