#' Open file for editing
#'
#' Opens a file for editing in RStudio, if that is the active environment, or
#' via [utils::file.edit()] otherwise. If the file does not exist, it is
#' created. If the parent directory does not exist, it is also created.
#'
#' @param path Path to target file.
#'
#' @return Target path, invisibly.
#' @export
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' edit_file("DESCRIPTION")
#' edit_file("~/.gitconfig")
#' }
edit_file <- function(path) {
  path <- user_path_prep(path)
  create_directory(path_dir(path))
  file_create(path)

  if (!interactive() || is_testing()) {
    ui_todo("Edit {ui_path(path)}")
  } else {
    ui_todo("Modify {ui_path(path)}")

    if (rstudioapi::isAvailable() && rstudioapi::hasFun("navigateToFile")) {
      rstudioapi::navigateToFile(path)
    } else {
      utils::file.edit(path)
    }
  }
  invisible(path)
}

#' Open configuration files
#'
#' * `edit_r_profile()` opens `.Rprofile`
#' * `edit_r_environ()` opens `.Renviron`
#' * `edit_r_makevars()` opens `.R/Makevars`
#' * `edit_git_config()` opens `.gitconfig` or `.git/config`
#' * `edit_git_ignore()` opens `.gitignore`
#' * `edit_rstudio_snippets(type)` opens `.R/snippets/{type}.snippets`
#'
#' The `edit_r_*()` and `edit_rstudio_*()` functions consult R's notion of
#' user's home directory. The `edit_git_*()` functions -- and \pkg{usethis} in
#' general -- inherit home directory behaviour from the \pkg{fs} package, which
#' differs from R itself on Windows. The \pkg{fs} default is more conventional
#' in terms of the location of user-level Git config files. See
#' [fs::path_home()] for more details.
#'
#' @return Path to the file, invisibly.
#'
#' @param scope Edit globally for the current __user__, or locally for the
#'   current __project__
#' @name edit
NULL

#' @export
#' @rdname edit
edit_r_profile <- function(scope = c("user", "project")) {
  ui_todo("Restart R for changes to take effect")
  path <- scoped_path_r(scope, ".Rprofile", envvar = "R_PROFILE_USER")
  edit_file(path)
}

#' @export
#' @rdname edit
edit_r_environ <- function(scope = c("user", "project")) {
  ui_todo("Restart R for changes to take effect")
  path <- scoped_path_r(scope, ".Renviron", envvar = "R_ENVIRON_USER")
  edit_file(path)
}

#' @export
#' @rdname edit
edit_r_buildignore <- function(scope = c("user", "project")) {
  path <- scoped_path_r(scope, ".Rbuildignore")
  edit_file(path)
}

#' @export
#' @rdname edit
edit_r_makevars <- function(scope = c("user", "project")) {
  path <- scoped_path_r(scope, ".R", "Makevars")
  edit_file(path)
}

#' @export
#' @rdname edit
#' @param type Snippet type. One of: "R", "markdown", "C_Cpp", "Tex",
#'   "Javascript", "HTML", "SQL"
edit_rstudio_snippets <- function(type = "R") {
  # RStudio snippets stored using R's definition of ~
  # https://github.com/rstudio/rstudio/blob/4febd2feba912b2a9f8e77e3454a95c23a09d0a2/src/cpp/core/system/Win32System.cpp#L411-L458
  path <- path_home_r(".R", "snippets", path_ext_set(tolower(type), "snippets"))
  edit_file(path)
}

scoped_path_r  <- function(scope = c("user", "project"), ..., envvar = NULL) {
  scope <- match.arg(scope)

  # Try environment variable in user scopes
  if (scope == "user" && !is.null(envvar)) {
    env <- Sys.getenv(envvar, unset = "")
    if (!identical(env, "")) {
      return(user_path_prep(env))
    }
  }

  root <- switch(scope,
    user = path_home_r(),
    project = proj_get()
  )
  path(root, ...)
}

# git paths ---------------------------------------------------------------
# Note that on windows R's definition of ~ is in a nonstandard place,
# so it is important to use path_home(), not path_home_r()

#' @export
#' @rdname edit
edit_git_config <- function(scope = c("user", "project")) {
  scope <- match.arg(scope)
  path <- switch(
    scope,
    user = path_home(".gitconfig"),
    project = proj_path(".git", "config")
  )
  invisible(edit_file(path))
}

#' @export
#' @rdname edit
edit_git_ignore <- function(scope = c("user", "project")) {
  scope <- match.arg(scope)
  file <- git_ignore_path(scope)
  if (scope == "user" && !file_exists(file)) {
    ui_done("Setting up new global gitignore: {ui_path(file)}")
    # Describe relative to home directory
    path <- path("~", path_rel(file, path_home()))
    git_config_set("core.excludesfile", path, global = TRUE)
    git_vaccinate()
  }
  invisible(edit_file(file))
}

git_ignore_path <- function(scope = c("user", "project")) {
  scope <- match.arg(scope)
  if (scope == "project") {
    return(proj_path(".gitignore"))
  }

  # .gitignore is most common, but .gitignore_global appears in prominent
  # places --> so we allow the latter, but prefer the former
  path <- path_home(".gitignore")
  if (file_exists(path)) {
    return(path)
  }

  alt_path <- path_home(".gitignore_global")
  if (file_exists(alt_path)) {
    return(alt_path)
  }

  path
}
