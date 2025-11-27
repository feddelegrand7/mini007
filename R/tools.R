#' Tools: Predefined Agent Tools
#'
#' @description
#' This file contains predefined tools that can be registered with agents,
#' inspired by crewAI's tool system. Tools extend agent capabilities by
#' providing specific functions for file operations, web interactions, and more.
#'
#' @importFrom ellmer tool type_object type_string type_boolean
#' @importFrom checkmate assert_string assert_flag assert_character
#' @importFrom cli cli_alert_success cli_alert_warning cli_alert_danger

#' Create Directory Tool - Change Working Directory
#'
#' @description
#' Creates a tool that allows agents to change the current working directory.
#' Useful for file management and navigation tasks.
#'
#' @return An ellmer Tool object for changing directories
#' @examples
#' \\dontrun{
#' tool <- change_directory_tool()
#' agent$register_tools(tool)
#' }
#' @export
change_directory_tool <- function() {
  change_directory_fn <- function(path) {
      checkmate::assert_string(path)

      if (!dir.exists(path)) {
        return(list(
          success = FALSE,
          error = paste("Directory does not exist:", path),
          current_directory = getwd()
        ))
      }

      tryCatch({
        old_wd <- getwd()
        setwd(path)
        new_wd <- getwd()

        list(
          success = TRUE,
          message = paste("Changed directory from", old_wd, "to", new_wd),
          previous_directory = old_wd,
          current_directory = new_wd
        )
      }, error = function(e) {
        list(
          success = FALSE,
          error = paste("Failed to change directory:", e$message),
          current_directory = getwd()
        )
      })
    }

  ellmer::tool(
    change_directory_fn,
    name = "change_directory",
    description = paste(
      "Change the current working directory to a specified path.",
      "Use this when you need to navigate to a different directory",
      "for file operations. Returns the new working directory path."
    ),
    arguments = list(
      path = ellmer::type_string(
        "The directory path to change to. Can be relative or absolute.",
        required = TRUE
      )
    )
  )
}

#' List Files Tool - List Directory Contents
#'
#' @description
#' Creates a tool that allows agents to list files and directories in a specified path.
#' Useful for exploring directory structures and finding files.
#'
#' @return An ellmer Tool object for listing files
#' @examples
#' \\dontrun{
#' tool <- list_files_tool()
#' agent$register_tools(tool)
#' }
#' @export
list_files_tool <- function() {
  list_files_fn <- function(path = ".", show_hidden = FALSE, full_names = FALSE) {
      if (is.null(path) || path == "") path <- "."
      if (is.null(show_hidden)) show_hidden <- FALSE
      if (is.null(full_names)) full_names <- FALSE

      if (!dir.exists(path)) {
        return(list(
          success = FALSE,
          error = paste("Directory does not exist:", path),
          files = character(0)
        ))
      }

      tryCatch({
        files <- list.files(
          path = path,
          all.files = show_hidden,
          full.names = full_names,
          include.dirs = TRUE
        )

        # Get file info for better context
        file_info <- file.info(file.path(path, files))
        directories <- files[file_info$isdir]
        regular_files <- files[!file_info$isdir]

        list(
          success = TRUE,
          path = normalizePath(path),
          total_items = length(files),
          directories = directories,
          files = regular_files,
          all_items = files
        )
      }, error = function(e) {
        list(
          success = FALSE,
          error = paste("Failed to list files:", e$message),
          files = character(0)
        )
      })
    }

  ellmer::tool(
    list_files_fn,
    name = "list_files",
    description = paste(
      "List files and directories in a specified path.",
      "Use this to explore directory contents, find files,",
      "or understand the structure of a directory."
    ),
    arguments = list(
      path = ellmer::type_string(
        "The directory path to list. Defaults to current working directory if not specified.",
        required = FALSE
      ),
      show_hidden = ellmer::type_boolean(
        "Whether to show hidden files (starting with '.'). Defaults to FALSE.",
        required = FALSE
      ),
      full_names = ellmer::type_boolean(
        "Whether to return full file paths. Defaults to FALSE.",
        required = FALSE
      )
    )
  )
}

#' Read File Tool - Read File Contents
#'
#' @description
#' Creates a tool that allows agents to read the contents of text files.
#' Useful for reading configuration files, code, documentation, and other text files.
#'
#' @return An ellmer Tool object for reading files
#' @examples
#' \\dontrun{
#' tool <- read_file_tool()
#' agent$register_tools(tool)
#' }
#' @export
read_file_tool <- function() {
  read_file_fn <- function(file_path, max_lines = NULL) {
      checkmate::assert_string(file_path)

      if (!file.exists(file_path)) {
        return(list(
          success = FALSE,
          error = paste("File does not exist:", file_path),
          content = ""
        ))
      }

      if (file.info(file_path)$isdir) {
        return(list(
          success = FALSE,
          error = paste("Path is a directory, not a file:", file_path),
          content = ""
        ))
      }

      tryCatch({
        # Read file contents
        if (!is.null(max_lines) && max_lines != "") {
          max_lines <- as.numeric(max_lines)
          if (!is.na(max_lines) && max_lines > 0) {
            content <- readLines(file_path, n = max_lines, warn = FALSE)
          } else {
            content <- readLines(file_path, warn = FALSE)
          }
        } else {
          content <- readLines(file_path, warn = FALSE)
        }

        file_size <- file.size(file_path)
        lines_read <- length(content)

        list(
          success = TRUE,
          file_path = normalizePath(file_path),
          content = paste(content, collapse = "\\n"),
          lines_read = lines_read,
          file_size_bytes = file_size,
          encoding = "UTF-8"
        )
      }, error = function(e) {
        list(
          success = FALSE,
          error = paste("Failed to read file:", e$message),
          content = ""
        )
      })
    }

  ellmer::tool(
    read_file_fn,
    name = "read_file",
    description = paste(
      "Read the contents of a text file.",
      "Use this to examine file contents, read configuration files,",
      "or analyze code and documentation. Supports text files only."
    ),
    arguments = list(
      file_path = ellmer::type_string(
        "The path to the file to read. Can be relative or absolute.",
        required = TRUE
      ),
      max_lines = ellmer::type_string(
        "Maximum number of lines to read. Defaults to all lines if not specified.",
        required = FALSE
      )
    )
  )
}

#' Write File Tool - Write Content to File
#'
#' @description
#' Creates a tool that allows agents to write content to text files.
#' Useful for creating configuration files, saving data, or generating documentation.
#'
#' @return An ellmer Tool object for writing files
#' @examples
#' \\dontrun{
#' tool <- write_file_tool()
#' agent$register_tools(tool)
#' }
#' @export
write_file_tool <- function() {
  write_file_fn <- function(file_path, content, append = FALSE) {
      checkmate::assert_string(file_path)
      checkmate::assert_string(content)
      if (is.null(append)) append <- FALSE

      # Create directory if it doesn't exist
      dir_path <- dirname(file_path)
      if (!dir.exists(dir_path)) {
        dir.create(dir_path, recursive = TRUE)
      }

      tryCatch({
        # Write content to file
        if (append) {
          write(content, file = file_path, append = TRUE)
          operation <- "appended to"
        } else {
          writeLines(content, file_path)
          operation <- "written to"
        }

        file_size <- file.size(file_path)

        list(
          success = TRUE,
          message = paste("Content successfully", operation, file_path),
          file_path = normalizePath(file_path),
          file_size_bytes = file_size,
          operation = ifelse(append, "append", "overwrite")
        )
      }, error = function(e) {
        list(
          success = FALSE,
          error = paste("Failed to write file:", e$message),
          file_path = file_path
        )
      })
    }

  ellmer::tool(
    write_file_fn,
    name = "write_file",
    description = paste(
      "Write content to a text file. Creates new files or overwrites existing ones.",
      "Use this to save data, create configuration files, or generate documentation.",
      "CAUTION: This will overwrite existing files without warning."
    ),
    arguments = list(
      file_path = ellmer::type_string(
        "The path where to write the file. Can be relative or absolute.",
        required = TRUE
      ),
      content = ellmer::type_string(
        "The content to write to the file.",
        required = TRUE
      ),
      append = ellmer::type_boolean(
        "Whether to append to existing file (TRUE) or overwrite (FALSE). Defaults to FALSE.",
        required = FALSE
      )
    )
  )
}

#' Create Custom Tool Helper
#'
#' @description
#' Helper function to create custom tools for agents, inspired by crewAI's @tool decorator.
#' This provides a simple interface for creating tools with validation and error handling.
#'
#' @param name Character string name for the tool
#' @param description Character string description of what the tool does
#' @param arguments ellmer type_object defining the tool's arguments
#' @param fun Function that implements the tool's logic
#' @return An ellmer Tool object
#' @examples
#' \\dontrun{
#' # Create a simple calculator tool
#' calc_tool <- create_tool(
#'   name = "calculator",
#'   description = "Perform basic arithmetic operations",
#'   arguments = ellmer::type_object(
#'     operation = ellmer::type_string(description = "The operation: add, subtract, multiply, divide"),
#'     a = ellmer::type_string(description = "First number"),
#'     b = ellmer::type_string(description = "Second number")
#'   ),
#'   fun = function(operation, a, b) {
#'     a <- as.numeric(a)
#'     b <- as.numeric(b)
#'     result <- switch(operation,
#'       "add" = a + b,
#'       "subtract" = a - b,
#'       "multiply" = a * b,
#'       "divide" = ifelse(b != 0, a / b, "Cannot divide by zero")
#'     )
#'     list(success = TRUE, result = result)
#'   }
#' )
#' }
#' @export
create_tool <- function(name, description, arguments, fun) {
  checkmate::assert_string(name)
  checkmate::assert_string(description)
  checkmate::assert_function(fun)

  ellmer::tool(
    fun,
    name = name,
    description = description,
    arguments = arguments
  )
}
