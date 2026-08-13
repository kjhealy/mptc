## Targeted invalidation of Quarto's freeze cache.
##
## Quarto keys `freeze: auto` on md5() of the raw .qmd bytes and nothing else:
## not `{{< include >}}`d files, not spreadsheets read in a chunk, not upstream
## targets pulled in with tar_read(). But the frozen payload has its includes
## already resolved, so a page whose real inputs have moved will happily serve
## stale output. That is the bug the old blanket `rm -rf _freeze/...` lines
## worked around, at the cost of re-executing those pages on every build and of
## firing on any `_targets.R` sourcing, including tar_outdated().
##
## Instead, stamp each affected page against its real inputs. When the stamp
## moves we drop that page's freeze entry, forcing re-execution, and drop its
## rendered HTML. Dropping the HTML is what invalidates the `site` target, since
## tar_quarto() tracks the whole of _site/ as that target's output. Pages with
## no hidden inputs are left alone: Quarto's own hashing already handles them.
##
## Note that only the *knitr* stage is frozen. Bibliographies, `{{< var >}}`
## substitutions from _variables.yml, and _quarto.yml settings are resolved by
## pandoc downstream of the freeze, so they update on their own and do not
## belong in a dependency set here.

# Stamps live under _targets/user/, the store location targets reserves for
# user-managed files.
freeze_stamp_path <- function(page) {
  here_rel(
    "_targets",
    "user",
    "freeze-stamps",
    paste0(gsub("/", "_", page), ".stamp")
  )
}

freeze_stamp <- function(files) {
  sums <- tools::md5sum(files)
  paste0(names(sums), "  ", sums, collapse = "\n")
}

# Invalidate one page if its dependencies have changed. Returns TRUE if it did.
bust_freeze <- function(page, files) {
  absent <- files[!fs::file_exists(files)]
  if (length(absent) > 0) {
    cli::cli_abort(c(
      "Can't stamp freeze dependencies for {.val {page}}.",
      x = "Missing file{?s}: {.file {absent}}."
    ))
  }

  stamp_path <- freeze_stamp_path(page)
  current <- freeze_stamp(files)
  previous <- if (fs::file_exists(stamp_path)) {
    paste(readLines(stamp_path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }

  if (identical(current, previous)) {
    return(invisible(FALSE))
  }

  freeze_dir <- here_rel("_freeze", page)
  if (fs::dir_exists(freeze_dir)) {
    fs::dir_delete(freeze_dir)
  }

  rendered_html <- here_rel("_site", paste0(page, ".html"))
  if (fs::file_exists(rendered_html)) {
    fs::file_delete(rendered_html)
  }

  fs::dir_create(fs::path_dir(stamp_path))
  writeLines(current, stamp_path)
  invisible(TRUE)
}

# Apply a whole page-to-dependencies table, reporting anything that moved.
bust_stale_freezes <- function(deps) {
  busted <- purrr::imap_lgl(deps, \(files, page) bust_freeze(page, files))
  if (any(busted)) {
    message(
      "Quarto freeze invalidated for: ",
      paste(names(busted)[busted], collapse = ", ")
    )
  }
  invisible(busted)
}


# Finding the hidden dependencies ----------------------------------------------

# The two things a .qmd can pull in that Quarto's hash won't notice: content
# spliced in with `{{< include >}}`, and R code brought in with source(). Both
# are resolved before knitr runs, so their content lands in the frozen result
# while the page's own bytes stay put. Recurses, because an included partial can
# itself include or source something.
qmd_hidden_deps <- function(qmd, seen = character(0)) {
  if (qmd %in% seen || !fs::file_exists(qmd)) {
    return(character(0))
  }
  lines <- readLines(qmd, warn = FALSE)

  includes <- stringr::str_match(
    lines,
    "\\{\\{<\\s*include\\s+(.+?)\\s*>\\}\\}"
  )[,
    2
  ]
  includes <- includes[!is.na(includes)]
  includes <- as.character(fs::path_norm(fs::path(fs::path_dir(qmd), includes)))

  # source(here::here("R", "slide-things.R")) and friends: pull the quoted
  # segments out of the here::here() call and rebuild the path from them
  calls <- stringr::str_match(lines, "source\\(\\s*here::here\\((.+?)\\)")[, 2]
  calls <- calls[!is.na(calls)]
  sourced <- purrr::map_chr(calls, \(x) {
    parts <- stringr::str_match_all(x, '"([^"]+)"')[[1]][, 2]
    if (length(parts) == 0) NA_character_ else paste(parts, collapse = "/")
  })
  sourced <- sourced[!is.na(sourced)]

  direct <- unique(c(includes, sourced))
  nested <- purrr::map(
    includes,
    \(f) qmd_hidden_deps(f, seen = c(seen, qmd))
  )
  unique(c(direct, unlist(nested, use.names = FALSE)))
}

# Build the page -> dependencies table for every page Quarto renders. `extra`
# adds what a scan can't see: spreadsheets reached through tar_read(), and the
# functions that shape them. Pages with nothing hidden are dropped -- Quarto's
# own hashing already handles those correctly, so stamping them would only
# cause needless re-execution.
build_freeze_deps <- function(qmd_files, extra = list()) {
  pages <- as.character(fs::path_ext_remove(qmd_files))
  deps <- purrr::set_names(purrr::map(qmd_files, qmd_hidden_deps), pages)

  for (page in names(extra)) {
    deps[[page]] <- unique(c(deps[[page]], extra[[page]]))
  }

  deps[purrr::map_int(deps, length) > 0]
}

# Every .qmd Quarto actually renders: no partials (leading _), and none of the
# folders _quarto.yml excludes from the render list.
rendered_qmds <- function(exclude = c("staging", "projects", "pdf_slides")) {
  files <- fs::dir_ls(".", glob = "*.qmd", recurse = TRUE, type = "file")
  files <- as.character(fs::path_rel(files))
  files <- files[!fs::path_file(files) |> stringr::str_starts("_")]
  files[
    !stringr::str_starts(
      files,
      paste0("(", paste(exclude, collapse = "|"), ")/")
    )
  ]
}
