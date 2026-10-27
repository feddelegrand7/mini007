#' @title Streaming Events
#'
#' @description
#' `Agent$invoke()`, `Workflow$run()` / `$resume()`, `WorkflowAgent$invoke()`
#' and `LeadAgent$invoke()` / `$resume()` accept \code{stream = TRUE} and an
#' optional \code{on_event} callback. While streaming, every unit of progress
#' is delivered to the callback as a `mini007_event` - a list with a `type`
#' discriminator - as soon as it happens, instead of only returning the final
#' result at the end. The return value of the call is unchanged: the same
#' final response you get without streaming.
#'
#' Events from nested components are forwarded to the outermost callback, so
#' a single `on_event` passed to a `LeadAgent` also receives the token deltas
#' of every `Agent` it delegates to, including Agents running inside a
#' `Workflow` wrapped with \code{$as_agent()}.
#'
#' @section Event fields:
#' \describe{
#'   \item{`type`}{`[character(1)]` The event type (see below).}
#'   \item{`source`}{`[character(1)]` Name of the Agent, Workflow or
#'     LeadAgent that emitted the event.}
#'   \item{`text`}{`[character(1) | NULL]` Text payload: a text delta for
#'     `"text_delta"` (see below), the full response or output for the
#'     `*_completed` and `*_output` events.}
#'   \item{`data`}{`[list]` Type-specific details (e.g. `tool_name`,
#'     `arguments`, `from_cache`, `pending`). Events are tagged with where
#'     they happened: `station` and `step` inside a Workflow, `task` (the plan
#'     index) and `agent` inside a LeadAgent. Tags from an inner component
#'     are kept, so a delta from an Agent in a Workflow wrapped as a
#'     LeadAgent sub-agent carries all four.}
#'   \item{`timestamp`}{`[POSIXct]` When the event was emitted.}
#' }
#'
#' @section Text deltas:
#' An LLM produces its answer a few characters at a time. While streaming,
#' each new fragment is delivered as soon as it is generated, in a
#' `"text_delta"` event: a delta is the text that is new since the previous
#' event, never the whole answer. Pasting the `text` of all deltas together,
#' in order, gives the full response. `"thinking_delta"` events work the same
#' way for the reasoning of reasoning models.
#'
#' @section Event types:
#' \describe{
#'   \item{Agent}{`"agent_started"`, `"text_delta"`, `"thinking_delta"`,
#'     `"tool_call"`, `"tool_result"`, `"agent_completed"`.}
#'   \item{Workflow}{`"workflow_started"`, `"station_started"`,
#'     `"station_retry"`, `"station_fallback"`, `"station_completed"`,
#'     `"hitl_request"`, `"workflow_output"`, `"workflow_failed"`.}
#'   \item{LeadAgent}{`"plan_created"`, `"task_started"`, `"task_completed"`,
#'     `"hitl_request"`, `"lead_output"`.}
#' }
#'
#' @section Cancellation:
#' Raising an error from inside `on_event` (e.g. \code{stop("cancelled")})
#' stops the run immediately. It is re-raised as a condition of class
#' `mini007_stream_cancelled`, which Workflow retries and fallbacks never
#' swallow, and the Agent's message history is kept in sync with whatever the
#' LLM produced before the cancellation.
#'
#' @section Parallel execution:
#' Stations in a parallel group run in separate `mirai` daemon processes, so
#' their token deltas cannot be streamed back. They still emit
#' `"station_started"` and `"station_completed"` events from the main process.
#'
#' @examples
#' \dontrun{
#' agent <- Agent$new(
#'   name = "poet",
#'   instruction = "You write short poems.",
#'   llm_object = ellmer::chat("openai/gpt-4.1-mini", echo = "none")
#' )
#'
#' # Print tokens to the console as they arrive
#' agent$invoke("A haiku about R", stream = TRUE)
#'
#' # Handle events yourself
#' agent$invoke("A haiku about R", on_event = function(event) {
#'   if (event$type == "text_delta") cat(event$text)
#' })
#' }
#'
#' @importFrom coro loop
#' @name mini007_event
NULL

#' @export
print.mini007_event <- function(x, ...) {
  cli::cli_text("{.cls mini007_event} {.strong {x$type}} from {.val {x$source}}")
  if (!is.null(x$text)) cli::cli_verbatim(x$text)
  if (length(x$data) > 0L) {
    cli::cli_text("data: {.field {names(x$data)}}")
  }
  invisible(x)
}

# Build a mini007_event object. Internal constructor shared by every class
# that streams, so callbacks see a single shape regardless of the emitter.
new_event <- function(type, source, text = NULL, ...) {
  structure(
    list(
      type      = type,
      source    = source,
      text      = text,
      data      = list(...),
      timestamp = Sys.time()
    ),
    class = c("mini007_event", "list")
  )
}

# Resolve the (stream, on_event) pair of a public method into the callback to
# use: NULL when not streaming, the user's callback when one is given (a
# callback implies streaming), the console printer otherwise.
resolve_on_event <- function(stream, on_event) {
  checkmate::assert_flag(stream)
  checkmate::assert_function(on_event, null.ok = TRUE)

  if (!is.null(on_event)) return(on_event)
  if (stream) return(new_console_handler())
  NULL
}

is_console_handler <- function(on_event) {
  isTRUE(attr(on_event, "mini007_console"))
}

# Deliver an event to a callback. Any error raised by the callback is
# re-signalled as `mini007_stream_cancelled` so callers can tell a deliberate
# cancellation apart from a station/LLM failure.
emit_event <- function(on_event, event) {
  if (is.null(on_event)) return(invisible(NULL))

  tryCatch(
    on_event(event),
    error = function(e) {
      if (inherits(e, "mini007_stream_cancelled")) stop(e)
      cli::cli_abort(
        "Streaming cancelled by {.arg on_event}: {conditionMessage(e)}",
        class = "mini007_stream_cancelled",
        parent = e,
        call = NULL
      )
    }
  )
  invisible(NULL)
}

# Wrap a callback so that every event passing through it gets extra `data`
# fields (e.g. the station or plan step it originated from). Fields already
# set by an inner emitter are kept.
forward_events <- function(on_event, ...) {
  if (is.null(on_event)) return(NULL)
  extra <- list(...)
  function(event) {
    for (nm in names(extra)) {
      if (is.null(event$data[[nm]])) event$data[[nm]] <- extra[[nm]]
    }
    on_event(event)
  }
}

# Call `handler$invoke(prompt)`, passing `on_event` only when streaming is
# active and the handler supports it - custom agent-like objects with a
# one-argument `invoke()` keep working, they just don't stream deltas.
invoke_with_events <- function(handler, prompt, on_event) {
  if (!is.null(on_event) && "on_event" %in% names(formals(handler$invoke))) {
    handler$invoke(prompt, on_event = on_event)
  } else {
    handler$invoke(prompt)
  }
}

# Default callback for `stream = TRUE`: writes token deltas to the console as
# they arrive. Lifecycle events are not echoed - the existing cli output of
# Workflow/LeadAgent already announces them. Each run gets its own handler so
# it can track whether the cursor sits at the start of a line (ellmer usually
# ends a stream with "\n", but not always).
new_console_handler <- function() {
  at_line_start <- TRUE
  ensure_newline <- function() {
    if (!at_line_start) cat("\n")
    at_line_start <<- TRUE
  }

  handler <- function(event) {
    switch(
      event$type,
      agent_started = {
        ensure_newline()
        cli::cli_text("{.strong {event$source}}:")
      },
      text_delta = if (length(event$text) == 1L && nzchar(event$text)) {
        cat(event$text, sep = "")
        utils::flush.console()
        at_line_start <<- endsWith(event$text, "\n")
      },
      tool_call = {
        ensure_newline()
        cli::cli_alert_info("Calling tool {.fn {event$data$tool_name}}")
      },
      tool_result = if (!is.null(event$data$error)) {
        ensure_newline()
        cli::cli_alert_danger("Tool {.fn {event$data$tool_name}} failed: {event$data$error}")
      },
      agent_completed = ensure_newline()
    )
    invisible(NULL)
  }
  attr(handler, "mini007_console") <- TRUE
  handler
}

# Translate one chunk yielded by `ellmer::Chat$stream(stream = "content")`
# into a mini007_event. Unknown content types are passed through in `data`
# instead of erroring, so newer ellmer content classes can't break a stream.
content_to_event <- function(chunk, source) {
  if (is.character(chunk)) {
    return(new_event("text_delta", source, text = paste(chunk, collapse = "")))
  }

  if (inherits(chunk, "ellmer::ContentToolRequest")) {
    return(new_event(
      "tool_call", source,
      tool_name = chunk@name,
      call_id   = chunk@id,
      arguments = chunk@arguments
    ))
  }

  if (inherits(chunk, "ellmer::ContentToolResult")) {
    error <- chunk@error
    if (inherits(error, "condition")) error <- conditionMessage(error)
    request <- chunk@request
    return(new_event(
      "tool_result", source,
      tool_name = if (!is.null(request)) request@name else NA_character_,
      call_id   = if (!is.null(request)) request@id else NA_character_,
      value     = chunk@value,
      error     = error
    ))
  }

  if (inherits(chunk, "ellmer::ContentThinking")) {
    return(new_event("thinking_delta", source, text = chunk@thinking))
  }

  if (inherits(chunk, "ellmer::ContentText")) {
    return(new_event("text_delta", source, text = chunk@text))
  }

  new_event("content", source, content = chunk)
}
