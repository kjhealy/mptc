library(targets)
library(tarchetypes)
suppressPackageStartupMessages(library(tidyverse))

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

# Force the index, syllabus, and schedule pages to always re-render; bah
# This works around targets not knowing about includes
system("[ ! -e _freeze/index ] || rm -rf _freeze/index/")
system("[ ! -e _freeze/schedule ] || rm -rf _freeze/schedule/")
system("[ ! -e _freeze/syllabus ] || rm -rf _freeze/syllabus/")
system("[ ! -e _site/index.html ] || rm -f _site/index.html")
system("[ ! -e _site/schedule ] || rm -rf _site/schedule/")
system("[ ! -e _site/syllabus ] || rm -rf _site/syllabus/")


# Ensure deletion_candidates has at least one dummy dir, to keep target branching happy
if (!fs::dir_exists(here::here("00_dummy_files"))) {
  fs::dir_create(here::here("00_dummy_files"))
}
if (!fs::dir_exists(here::here("00_dummy_files/figure-revealjs"))) {
  fs::dir_create(here::here("00_dummy_files/figure-revealjs"))
}
fs::file_create(here::here("00_dummy_files/figure-revealjs/00_dummy.png"))

get_flipbookr_orphans <- function() {
  all_candidates <- fs::dir_ls(
    glob = "*_files/figure-revealjs/*.png",
    recurse = TRUE
  )
  all_candidates <- all_candidates[stringr::str_detect(
    all_candidates,
    "_site",
    negate = TRUE
  )]
  if (length(all_candidates) == 0) {
    return(character(0))
  } else {
    return(all_candidates)
  }
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


get_leftover_dirs <- function(
  excludes = "_site|_targets|example|assignment|content"
) {
  # the figure-revealjs subdirs will all have been moved
  deletion_candidates <- fs::dir_ls(glob = "*_files", recurse = TRUE)
  deletion_candidates <- deletion_candidates[stringr::str_detect(
    deletion_candidates,
    excludes,
    negate = TRUE
  )]
  if (length(deletion_candidates) == 0) {
    return(character(0))
  } else {
    return(deletion_candidates)
  }
}

remove_leftover_dirs <- function(dirs) {
  if (length(dirs) == 0) {
    return(character(0))
  }
  if (is.null(dirs)) {
    return(character(0))
  } else {
    fs::dir_delete(dirs)
  }
}

## THE MAIN PIPELINE ----
list(
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
  tar_quarto(site, path = ".", quiet = FALSE),

  tar_files(rendered_slides, {
    # Force dependencies
    site
    fl <- list.files(here_rel("slides"), pattern = "\\.qmd", full.names = TRUE)
    paste0("_site/", stringr::str_replace(fl, "qmd", "html"))
  }),

  ## Fix any flipbookr leftover files
  tar_files(flipbookr_orphans, {
    # Flipbooks created in the top level
    get_flipbookr_orphans()
  }),

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
    rendered_slides
    # Top-level flipbookr dirs now empty
    get_leftover_dirs()
  }),

  tar_invalidate(empty_dirs),

  tar_target(
    empty_dirs,
    {
      remove_leftover_dirs(flipbookr_dirs)
    },
    pattern = map(flipbookr_dirs)
  ),

  ## Upload site ----
  tar_target(deploy_script, here_rel("deploy.sh"), format = "file"),
  tar_target(deploy_site, {
    # Force dependencies
    site
    # Run the deploy script if both conditions are met
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
