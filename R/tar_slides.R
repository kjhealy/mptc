library(kjhslides)
library(ggthemes)
library(usethis)


## Use decktape (via kjhslides) to convert HTML slides to PDF.
## Return a relative path to the PDF to keep targets happy.

html_to_pdf <- function(slide_path) {
  path_sans_ext <- tools::file_path_sans_ext(slide_path)
  outdir_path <- fs::path_real(dirname(slide_path))
  kjhslides::kjh_decktape_one_slide(infile = slide_path, outdir = outdir_path)
  return(paste0(tools::file_path_sans_ext(slide_path), ".pdf"))
}
