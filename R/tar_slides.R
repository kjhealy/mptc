library(kjhslides)
library(ggthemes)
library(usethis)

# We need to return the path to the rendered HTML file. In this case,
# rmarkdown::render() *does* return a path, but it returns an absolute path,
# which makes the targets pipline less portable. So we return our own path to
# the HTML file instead.
# render_quarto <- function(slide_path) {
#   quarto::quarto_render(slide_path, quiet = FALSE)
#   #return(paste0(tools::file_path_sans_ext(slide_path), ".html"))
# }

## Use decktape (via kjhslides) to convert xaringan HTML slides to PDF.
## Return a relative path to the PDF to keep targets happy.

html_to_pdf <- function(slide_path) {
  path_sans_ext <- tools::file_path_sans_ext(slide_path)
  outdir_path <- fs::path_real(dirname(slide_path))
  kjhslides::kjh_decktape_one_slide(infile = slide_path, outdir = outdir_path)
  return(paste0(tools::file_path_sans_ext(slide_path), ".pdf"))
}
