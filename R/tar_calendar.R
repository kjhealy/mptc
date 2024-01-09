suppressPackageStartupMessages(library(lubridate))
library(glue)
library(calendar)

# Once again, {targets} needs the path of the saved file so we return it here
save_ical <- function(df, path) {
  calendar::ic_write(df, path)
  return(path)
}


format_days <- function(date, day2, date_end) {
  dplyr::case_when(
    is.na(date_end) & is.na(date) & !is.na(day2) ~
      glue::glue('{format(day2, "%b %e")}'),
    is.na(date_end) & !is.na(date) & !is.na(day2) ~
      glue::glue('{format(date, "%b %e")} / {format(day2, "%b %e")}'),
    is.na(date_end) & !is.na(date) & is.na(day2) ~
      glue::glue('{format(date, "%b %e")}</strong>'),
    !is.na(date_end) & is.na(date) & is.na(day2) ~
      glue::glue('Due <strong>{format(date_end, "%b %e")}</strong>'),
    TRUE ~ glue::glue('{format(date, "%b %e")} / {format(day2, "%b %e")}')
  )
}

# Read the schedule xlsx file and create/format columns for displaying on the
# schedule page. Returns a data frame with all rows tidyr::nested by group to make it
# easier to display the schedule by group
build_schedule_for_page <- function(schedule_file) {
  schedule <- readxl::read_xlsx(schedule_file)  |>
    dplyr::mutate(group = forcats::fct_inorder(group),
                  subgroup = forcats::fct_inorder(subgroup),
                  date = lubridate::ymd(date),
                  day2 = lubridate::ymd(day2),
                  date_end = lubridate::ymd(date_end),
                  deadline = lubridate::ymd(deadline),
                  var_note = ifelse(!is.na(note),
                                    glue::glue('<br><span class="content-note">{note}</span>'),
                                    glue::glue(""))) |>
    dplyr::mutate(var_title = ifelse(!is.na(content),
                                     glue::glue('<span class="content-title">{title}</span>'),
                                     glue::glue('{title}'))) |>
    dplyr::mutate(var_deadline = ifelse(!is.na(deadline),
                                        glue::glue('&emsp;&emsp;<small>(Submit by {deadline})</small>'),
                                        glue::glue(""))) |>
    dplyr::mutate(var_content = ifelse(!is.na(content),
                                       glue::glue('<a href="{content}.qmd"><i class="fa-solid fa-book-open-reader fa-lg"></i></a>'),
                                       glue::glue('<font color="#e9ecef"><i class="fa-solid fa-book-open-reader fa-lg"></i></font>'))) |>
    dplyr::mutate(var_example = ifelse(!is.na(example),
                                       glue::glue('<a href="{example}.qmd"><i class="fa-solid fa-laptop-code fa-lg"></i></a>'),
                                       glue::glue('<font color="#e9ecef"><i class="fa-solid fa-laptop-code fa-lg"></i></font>'))) |>
    dplyr::mutate(var_assignment = ifelse(!is.na(assignment),
                                          glue::glue('<a href="{assignment}.qmd"><i class="fa-solid fa-pen-ruler fa-lg"></i></a>'),
                                          glue::glue('<font color="#e9ecef"><i class="fa-solid fa-pen-ruler fa-lg"></i></font>'))) |>
    dplyr::mutate(col_date = format_days(date, day2, date_end)) |>
    dplyr::mutate(col_title = glue::glue('{var_title}{var_deadline}{var_note}')) |>
    dplyr::mutate(col_content = var_content,
                  col_example = var_example,
                  col_assignment = var_assignment)

  schedule_nested <- schedule |>
    dplyr::select(group, subgroup,
                  ` ` = col_date, Topic = col_title, Content = col_content,
                  Example = col_example, Assignment = col_assignment) |>
    dplyr::group_by(group) |>
    tidyr::nest() |>
    dplyr::mutate(subgroup_count = purrr::map(data, ~dplyr::count(.x, subgroup)),
                  subgroup_index = purrr::map(subgroup_count, ~{
                    .x |> dplyr::pull(n) |> rlang::set_names(.x$subgroup)
                  }))

  return(schedule_nested)
}

# Read the schedule CSV file and create a dataset formatted as iCal data that
# calendar::ic_write() can use
build_ical <- function(schedule_file, base_url, page_suffix, class_number) {
  dtstamp <- calendar::ic_char_datetime(lubridate::now("UTC"), zulu = TRUE)

  schedule <- readxl::read_xlsx(schedule_file) |>
    dplyr::mutate(date = lubridate::ymd(date)) |>
    dplyr::mutate(day2 = lubridate::ymd(day2)) |>
    dplyr::mutate(deadline = lubridate::ymd(deadline)) |>
    tidyr::pivot_longer(date:day2, values_to = "date") |> # tidyr::pivot so all class days in calendar
    dplyr::select(-name) |>
    dplyr::mutate(session = dplyr::if_else(is.na(content), glue::glue(""), glue::glue("({subgroup}) "))) |>
    dplyr::mutate(summary = glue::glue("{session}{title}")) |>
    dplyr::mutate(date_start_dt = date,
                  date_end_dt = dplyr::if_else(is.na(date_end), date_start_dt, date_end)) |>
    dplyr::mutate(date_start_cal = purrr::map(date_start_dt, ~as.POSIXct(., format = "%B %d, %Y")),
                  date_end_cal = purrr::map(date_end_dt, ~as.POSIXct(., format = "%B %d, %Y"))) |>
    dplyr::mutate(url = dplyr::coalesce(content, example, assignment),
                  url = dplyr::if_else(is.na(url), glue::glue(""), glue::glue("{base_url}{url}{page_suffix}"))) |>
    tidyr::unnest(cols = c(date_start_cal, date_end_cal)) |>
    tidyr::drop_na(date_start_cal, date_end_cal)

  schedule_ics <- schedule |>
    dplyr::mutate(id = dplyr::row_number()) |>
    dplyr::group_by(id) |>
    tidyr::nest() |>
    dplyr::mutate(ical = purrr::map(data,
                                    ~calendar::ic_event(start = .$date_start_cal[[1]],
                                                        end = .$date_end_cal[[1]] + 24*60*60,
                                                        summary = .$summary[[1]],
                                                        more_properties = TRUE,
                                                        event_properties = c("DESCRIPTION" = .$url[[1]],
                                                                             "DTSTAMP" = dtstamp)))) |>
    dplyr::ungroup() |>
    dplyr::select(-id, -data) |>
    tidyr::unnest(ical) |>
    calendar::ical() |>
    dplyr::rename(`DTSTART;VALUE=DATE` = DTSTART,
                  `DTEND;VALUE=DATE` = DTEND)

  return(schedule_ics)
}
