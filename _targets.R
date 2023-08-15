library(targets)
library(tarchetypes)
suppressPackageStartupMessages(library(tidyverse))

## Variables and options
class_number <- "SOCIOL 880-1"
base_url <- "https://visualizingsociety.com/"
page_suffix <- ".html"

options(tidyverse.quiet = TRUE,
        dplyr.summarise.inform = FALSE)

tar_option_set(
  packages = c("tibble"),
  format = "rds",
  workspace_on_error = TRUE
)

# Deployment flag—one of two tests to deploy_site target.
# See deploy_site below for the user condition

Sys.setenv(DEPLOY_MPTC = TRUE)

# There's no way to get a relative path directly out of here::here(), but
# fs::path_rel() works fine with it (see
# https://github.com/r-lib/here/issues/36#issuecomment-530894167)
here_rel <- function(...) {fs::path_rel(here::here(...))}

## Load functions for the pipeline
source("R/tar_slides.R")
source("R/tar_projects.R")
source("R/tar_data.R")
source("R/tar_calendar.R")


## THE MAIN PIPELINE ----
list(
  ## Run all the data building and copying targets ----
  ## save_data,

  ### Link all these data building and copying targets into individual dependencies ----
  ## tar_combine(copy_data, tar_select_targets(save_data, starts_with("copy_"))),
  ## tar_combine(build_data, tar_select_targets(save_data, starts_with("data_"))),


  ## Project folders ----

  ### Zip up each project folder ----
  #
  # Get a list of all folders in the project folder, create dynamic branches,
  # then create a target for each that runs the custom zippy() function, which
  # uses system2() to zip the folder and returns a path to keep targets happy
  # with `format = "file"`
  #
  # The main index.qmd page loads project_zips as a target to link it as a dependency
  #
  # Use tar_force() and always run this because {targets} seems to overly cache
  # the results of list.dirs()
  ##tar_force(project_paths,
  ##          list.dirs(here_rel("projects"),
  ##                    full.names = FALSE, recursive = FALSE),
  ##          force = TRUE),
  ## tar_target(project_files, project_paths, pattern = map(project_paths)),
  ##tar_target(project_zips, {
  ##  copy_data
  ##  build_data
  ##  zippy(project_files, "projects")
  ##},
  ## pattern = map(project_files),
  ## format = "file"),


  ## Class schedule calendar ----
  tar_target(schedule_file, here_rel("data", "schedule.xlsx"), format = "file"),
  tar_target(schedule_page_data, build_schedule_for_page(schedule_file)),
  tar_target(schedule_ical_data, build_ical(schedule_file, base_url, page_suffix, class_number)),
  tar_target(schedule_ical_file,
             save_ical(schedule_ical_data,
                       here_rel("files", "schedule.ics")),
             format = "file"),


  ## Knit the README ----
  tar_target(workflow_graph, tar_mermaid(targets_only = TRUE, outdated = FALSE,
                                         legend = FALSE, color = FALSE)),
  tar_quarto(readme, here_rel("README.qmd")),


  ## Build site ----
  tar_quarto(site, path = "."),


  ## Upload site ----
  tar_target(deploy_script, here_rel("deploy.sh"), format = "file"),
  tar_target(deploy_site, {
    # Force dependencies
    site
    # Run the deploy script if both conditions are met
    if (Sys.info()["user"] != "kjhealy" | Sys.getenv("DEPLOY_MPTC") != "TRUE") message("Deployment vars not set. Will not deploy site.")
    if (Sys.info()["user"] == "kjhealy" & Sys.getenv("DEPLOY_MPTC") == "TRUE") message("Running deployment script ...")
    if (Sys.info()["user"] == "kjhealy" & Sys.getenv("DEPLOY_MPTC") == "TRUE") processx::run(paste0("./", deploy_script), echo = TRUE)
  })
)
