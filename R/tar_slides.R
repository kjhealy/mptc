library(kjhslides)
library(ggthemes)
library(usethis)


## Use decktape (via kjhslides) to convert HTML slides to PDF.
## Return a relative path to the PDF to keep targets happy.

## Write the PDFs into the *source* slides/ folder, not into _site/slides/.
##
## `quarto render` deletes files it doesn't know about from the output
## directory, so PDFs written straight into _site/slides/ were wiped by every
## render. quarto_pdfs is a format = "file" target, so it then saw its outputs
## missing and rebuilt all eighteen decks, every single build -- and writing
## them back into _site/ dirtied the `site` target's own tracked output, which
## re-rendered, which deleted them again.
##
## Generating them into slides/ and declaring "slides/*.pdf" as a resource in
## _quarto.yml means Quarto *copies* them into _site/slides/ instead. The
## published URLs are unchanged, so the links from slide_buttons() still work.
## outdir stays a plain relative path rather than here_rel("slides"): this runs
## on a crew worker, and a literal avoids relying on a helper defined in
## _targets.R being shipped to it. Workers run with the project root as their
## working directory, which is what the previous version assumed too.
html_to_pdf <- function(slide_path, outdir = "slides") {
  kjhslides::kjh_decktape_one_slide(infile = slide_path, outdir = outdir)
  as.character(
    fs::path(outdir, fs::path_ext_set(fs::path_file(slide_path), "pdf"))
  )
}
