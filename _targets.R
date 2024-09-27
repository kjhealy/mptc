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


# Force the schedule page to always re-render; bah
system("[ ! -e _freeze/schedule ] || rm -rf _freeze/schedule")

# Force the shell example pages to always re-render; bah
# system("[ ! -e _freeze/example/03-example ] || rm -rf _freeze/example/03-example")


## THE MAIN PIPELINE ----
list(
  ## Class schedule calendar ----
  tar_target(schedule_file, here_rel("data", "schedule.xlsx"), format = "file"),
  tar_target(schedule_page_data, build_schedule_for_page(schedule_file)),
  tar_target(schedule_ical_data, build_ical(schedule_file, base_url, page_suffix, class_number)),
  tar_target(schedule_ical_file,
    save_ical(
      schedule_ical_data,
      here_rel("files", "schedule.ics")
    ),
    format = "file"
  ),

  ## Data resource list
  tar_target(data_source_file, here_rel("data", "data_sources.xlsx"), format = "file"),
  tar_target(data_source_df, build_data_sources_df(data_source_file)),

  ## README ----
  # tar_target(workflow_graph, tar_mermaid(targets_only = TRUE, outdated = FALSE,
  #                                        legend = FALSE, color = FALSE)),
  # tar_quarto(readme, here_rel("README.qmd")),


  ## Build site ----
  tar_quarto(site, path = ".", quiet = FALSE),


  ## Upload site ----
  tar_target(deploy_script, here_rel("deploy.sh"), format = "file"),
  tar_target(deploy_site, {
    # Force dependencies
    site
    # Run the deploy script if both conditions are met
    # deploy_username and deploy_site are set in _variables.yml
    if (Sys.info()["user"] != yaml_vars$deploy$user | yaml_vars$deploy$site != TRUE) message("Deployment vars not set. Will not deploy site.") # nolint
    if (Sys.info()["user"] == yaml_vars$deploy$user & yaml_vars$deploy$site == TRUE) message("Running deployment script ...") # nolint
    if (Sys.info()["user"] == yaml_vars$deploy$user & yaml_vars$deploy$site == TRUE) processx::run(paste0("./", deploy_script), echo = TRUE) # nolint
  })
)
