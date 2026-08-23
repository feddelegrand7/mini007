#' @title Pending HITL Request
#'
#' @description
#' When a `Workflow` or `LeadAgent` is run with \code{hitl_mode = "pause"},
#' reaching a Human-In-The-Loop step does not block on \code{readline()}.
#' Instead, \code{$run()} / \code{$invoke()} return immediately with a
#' `mini007_pending` object describing the paused step. Inspect it, then call
#' \code{$resume()} on the same `Workflow`/`LeadAgent` with the chosen
#' \code{action} to continue execution.
#'
#' This makes HITL usable outside an interactive console - e.g. from a Shiny
#' app, a Plumber endpoint, or a batch job that persists the pending request
#' and resumes it later.
#'
#' @name mini007_pending
NULL

#' @title Check whether a value is a pending HITL request
#'
#' @description
#' Returns `TRUE` if `x` is a `mini007_pending` object, as returned by
#' \code{Workflow$run()}, \code{Workflow$resume()}, \code{LeadAgent$invoke()},
#' or \code{LeadAgent$resume()} when execution pauses for human input.
#'
#' @param x An object to test.
#'
#' @return `[logical(1)]`
#'
#' @examples
#' wf <- Workflow$new("W")
#' wf$add_station("s1", function(x) x)
#' wf$set_hitl(1L, mode = "pause")
#' result <- wf$run("hello")
#' is_pending(result)
#'
#' @export
is_pending <- function(x) {
  inherits(x, "mini007_pending")
}

#' @export
print.mini007_pending <- function(x, ...) {
  cli::cli_rule(left = glue::glue("Pending HITL request - step {x$step}"))
  cli::cli_text("Request id: {.val {x$request_id}}")
  cli::cli_text("Station/Agent: {.strong {x$station}}")
  cli::cli_alert_info("Input:")
  cli::cli_verbatim(x$input)
  cli::cli_alert_info("Proposed output:")
  cli::cli_verbatim(x$proposed_output)
  cli::cli_alert_warning(
    "Call {.code $resume(\"{x$request_id}\", action = \"continue\"|\"edit\"|\"abort\")} to proceed."
  )
  invisible(x)
}

# Build a mini007_pending object. Internal constructor shared by Workflow and
# LeadAgent so both expose the same shape to callers.
new_pending <- function(request_id, step, station, input, proposed_output) {
  structure(
    list(
      request_id      = request_id,
      step            = step,
      station         = station,
      input           = input,
      proposed_output = proposed_output
    ),
    class = c("mini007_pending", "list")
  )
}
