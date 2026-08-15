library(targets)
library(tarchetypes)
suppressPackageStartupMessages(library(tidyverse))

## Parallelize things --- when we build the PDFs
## it'll take forever otherwise
library(crew)
tar_option_set(
  controller = crew_controller_local(workers = 16)
)


## Variables and options
yaml_vars <- yaml::read_yaml(here::here("_variables.yml"))

class_number <- yaml_vars$course$number
page_suffix <- ".html"
base_url <- yaml_vars$course$url

options(
  tidyverse.quiet = TRUE,
  dplyr.summarise.inform = FALSE
)

tar_option_set(
  packages = c("tibble"),
  format = "rds",
  workspace_on_error = TRUE
)

# There's no way to get a relative path directly out of here::here(), but
# fs::path_rel() works fine with it (see
# https://github.com/r-lib/here/issues/36#issuecomment-530894167)
here_rel <- function(...) {
  fs::path_rel(here::here(...))
}

## Load functions for the pipeline
source("R/tar_slides.R")
source("R/tar_projects.R")
source("R/tar_data.R")
source("R/tar_calendar.R")
source("R/tar_freeze.R")

# Quarto hashes only the raw bytes of a .qmd, so an edit to an include, to a
# source()d script, or to a spreadsheet read in a chunk leaves the page frozen
# and silently stale. Scan every page for the dependencies that hash can't see
# and invalidate only those pages whose real inputs have moved. See
# R/tar_freeze.R.
#
# `extra` covers what a scan can't: data reached through tar_read(), and the
# functions that shape it. Everything else is found by reading the .qmd files.
freeze_deps <- build_freeze_deps(
  rendered_qmds(),
  extra = list(
    "index" = c("data/schedule.xlsx", "R/tar_calendar.R"),
    "syllabus/index" = c("data/schedule.xlsx", "R/tar_calendar.R"),
    "schedule/index" = c("data/schedule.xlsx", "R/tar_calendar.R"),
    # The old rm -rf hack missed this page entirely, so the resources table
    # never refreshed when data_sources.xlsx changed
    "content/index" = c("data/data_sources.xlsx", "R/tar_data.R")
  )
)

bust_stale_freezes(freeze_deps)

# Superseded by the stamped invalidation above. These ran unconditionally on
# every sourcing of this file, which re-executed three pages on every build and
# meant that even tar_outdated() deleted build artefacts.
# system("[ ! -e _freeze/index ] || rm -rf _freeze/index/")
# system("[ ! -e _freeze/schedule ] || rm -rf _freeze/schedule/")
# system("[ ! -e _freeze/syllabus ] || rm -rf _freeze/syllabus/")
# system("[ ! -e _site/index.html ] || rm -f _site/index.html")
# system("[ ! -e _site/schedule ] || rm -rf _site/schedule/")
# system("[ ! -e _site/syllabus ] || rm -rf _site/syllabus/")

# Ensure deletion_candidates has at least one dummy dir, to keep target branching happy
if (!fs::dir_exists(here::here("00_dummy_files"))) {
  fs::dir_create(here::here("00_dummy_files"))
}
if (!fs::dir_exists(here::here("00_dummy_files/figure-revealjs"))) {
  fs::dir_create(here::here("00_dummy_files/figure-revealjs"))
}
fs::file_create(here::here("00_dummy_files/figure-revealjs/00_dummy.png"))

# flipbookr writes its figures to <deck>_files/figure-revealjs/ in the *working
# directory* -- the project root -- rather than next to the slide that produced
# them. The leftovers therefore only ever appear at the top level, and that is
# the only place worth looking.
#
# The previous versions of these three functions globbed the whole tree and then
# spared whatever matched the substrings "_site|_targets|example|assignment|
# content". Anything else -- a *_files directory under assets/, files/,
# staging/, projects/ or renv/ -- was handed to fs::dir_delete(). Nothing in the
# project matches today, so this was latent rather than live, but a recursive
# delete guarded by a substring denylist is a bad way to find that out.
flipbookr_leftover_dirs <- function() {
  as.character(fs::dir_ls(".", type = "directory", regexp = "_files$"))
}

get_flipbookr_orphans <- function() {
  figure_dirs <- fs::path(flipbookr_leftover_dirs(), "figure-revealjs")
  figure_dirs <- figure_dirs[fs::dir_exists(figure_dirs)]
  if (length(figure_dirs) == 0) {
    return(character(0))
  }
  as.character(fs::dir_ls(figure_dirs, glob = "*.png"))
}

# Put the orphans in _site/ *and* in _freeze
relocate_orphans <- function(file) {
  if (length(file) == 0) {
    return(character(0))
  }
  if (is.null(file)) {
    return(character(0))
  }
  destdir_site <- paste0("_site/slides/", fs::path_dir(file))
  destdir_freeze <- stringr::str_remove(fs::path_dir(file), "_files")
  destdir_freeze <- paste0("_freeze/slides/", destdir_freeze)
  if (!fs::dir_exists(here::here(destdir_site))) {
    fs::dir_create(here::here(destdir_site))
  }
  fs::file_copy(file, paste0("_site/slides/", file), overwrite = TRUE)
  if (!fs::dir_exists(here::here(destdir_freeze))) {
    fs::dir_create(here::here(destdir_freeze))
  }
  file_freeze <- stringr::str_remove(file, "_files")
  fs::file_copy(file, paste0("_freeze/slides/", file_freeze), overwrite = TRUE)
}


get_leftover_dirs <- function() {
  # the figure-revealjs subdirs will all have been moved by now
  flipbookr_leftover_dirs()
}

remove_leftover_dirs <- function(dirs) {
  if (length(dirs) == 0 || is.null(dirs)) {
    return(character(0))
  }
  # Belt and braces ahead of a recursive delete: refuse anything that isn't a
  # top-level *_files directory, whatever the caller thinks it's passing
  unsafe <- dirs[fs::path_dir(dirs) != "." | !stringr::str_ends(dirs, "_files")]
  if (length(unsafe) > 0) {
    cli::cli_abort(c(
      "Refusing to delete unexpected {.arg dirs}.",
      x = "Not {?a/} top-level {.file *_files} director{?y/ies}: {.file {unsafe}}."
    ))
  }
  fs::dir_delete(dirs)
}

## THE MAIN PIPELINE ----
list(
  ## Project folders ----
  ### Zip up each project folder ----
  #
  # Get a list of all folders in the project folder, create dynamic branches,
  # then create a target for each that runs the custom zippy() function, which
  # uses system2() to zip the folder and returns a path to keep targets happy
  # with `format = "file"`
  #
  # Use tar_force() and always run this because {targets} seems to overly cache
  # the results of list.dirs()
  #
  # The scan has to carry a digest of each folder's *contents*, and it has to
  # happen inside the forced target. Branching on folder names alone meant a
  # name never changed, so editing a file inside a project folder left its .zip
  # untouched. Computing the digest in a downstream target doesn't help either:
  # that target only re-runs when the names change, so it never gets to look.
  tar_force(
    project_manifest,
    {
      list.dirs(here_rel("projects"), full.names = FALSE, recursive = FALSE) |>
        purrr::map(project_contents) |>
        purrr::list_rbind()
    },
    force = TRUE
  ),
  tar_target(
    project_files,
    project_manifest,
    pattern = map(project_manifest)
  ),
  tar_target(
    project_zips,
    {
      zippy(project_files$folder, "projects")
    },
    pattern = map(project_files),
    format = "file"
  ),

  ## Class schedule calendar ----
  tar_target(schedule_file, here_rel("data", "schedule.xlsx"), format = "file"),
  tar_target(schedule_page_data, build_schedule_for_page(schedule_file)),
  tar_target(
    schedule_ical_data,
    build_ical(schedule_file, base_url, page_suffix, class_number)
  ),
  tar_target(
    schedule_ical_file,
    save_ical(
      schedule_ical_data,
      here_rel("files", "schedule.ics")
    ),
    format = "file"
  ),

  ## Data resource list
  tar_target(
    data_source_file,
    here_rel("data", "data_sources.xlsx"),
    format = "file"
  ),
  tar_target(data_source_df, build_data_sources_df(data_source_file)),

  ## README ----
  # tar_target(workflow_graph, tar_mermaid(targets_only = TRUE, outdated = FALSE,
  #                                        legend = FALSE, color = FALSE)),
  # tar_quarto(readme, here_rel("README.qmd")),

  ## Build site ----
  #
  # extra_files picks up what `quarto inspect` doesn't report as project input:
  # the slide/site theme and the images. Neither affects code execution, so the
  # freeze cache is no obstacle -- they just need to invalidate `site` so that
  # Quarto is re-run at all. This mattered less when the old rm -rf lines forced
  # `site` to rebuild on every single invocation.
  tar_quarto(
    site,
    path = ".",
    extra_files = c("_extensions", "assets"),
    quiet = FALSE
  ),

  tar_files(rendered_slides, {
    # Force dependencies
    site_ready <- site
    fl <- list.files(here_rel("slides"), pattern = "\\.qmd", full.names = TRUE)
    paste0("_site/", stringr::str_replace(fl, "qmd", "html"))
  }),

  ## Fix any flipbookr leftover files
  tar_files(flipbookr_orphans, {
    # Force dependencies: the orphans don't exist until the site has rendered,
    # so without this targets is free to look for them too early and find none
    site_ready <- site
    # Flipbooks created in the top level
    get_flipbookr_orphans()
  }),

  ## Create PDFs of slides
  tar_target(
    quarto_pdfs,
    {
      html_to_pdf(rendered_slides)
    },
    pattern = map(rendered_slides),
    format = "file"
  ),

  ## Clean up after flipbookr
  tar_target(
    move_orphans,
    {
      relocate_orphans(flipbookr_orphans)
    },
    pattern = map(flipbookr_orphans),
    format = "file"
  ),

  ## Remove any flipbookr leftover dirs
  tar_files(flipbookr_dirs, {
    # Force dependencies (no PDFs of slides so we use rendered_slides)
    rendered_slides_ready <- rendered_slides
    # Top-level flipbookr dirs now empty
    get_leftover_dirs()
  }),

  # Always re-run the cleanup. This used to be a tar_invalidate(empty_dirs) call
  # sitting in the pipeline list, which deleted the target's metadata as a side
  # effect of *sourcing* this file. Any sourcing not followed by a successful
  # build of empty_dirs -- tar_outdated(), tar_visnetwork(), an interrupted run,
  # a fresh clone -- then made the next sourcing fail outright, because the name
  # it wanted to invalidate was no longer in the metadata. Saying "always run"
  # with a cue is declarative and touches nothing on disk.
  tar_target(
    empty_dirs,
    {
      remove_leftover_dirs(flipbookr_dirs)
    },
    pattern = map(flipbookr_dirs),
    cue = tar_cue(mode = "always")
  ),

  ## Upload site ----
  tar_target(deploy_script, here_rel("deploy.sh"), format = "file"),
  tar_target(deploy_site, {
    # Force dependencies
    site_ready <- site
    #pdfs_ready <- quarto_pdfs

    # Run the deploy script if both deploy conditions are met
    # deploy_username and deploy_site are set in _variables.yml
    if (
      Sys.info()["user"] != yaml_vars$deploy$user |
        yaml_vars$deploy$site != TRUE
    ) {
      message("Deployment vars not set. Will not deploy site.")
    } # nolint
    if (
      Sys.info()["user"] == yaml_vars$deploy$user &
        yaml_vars$deploy$site == TRUE
    ) {
      message("Running deployment script ...")
    } # nolint
    if (
      Sys.info()["user"] == yaml_vars$deploy$user &
        yaml_vars$deploy$site == TRUE
    ) {
      processx::run(paste0("./", deploy_script), echo = TRUE)
    } # nolint
  })
)
