#' @title Workflow
#'
#' @description
#' An R6 class for building sequential multi-agent pipelines. A `Workflow`
#' is composed of **Stations** (processing units - an `Agent`, a
#' `WorkflowAgent`, or any plain R function) connected by **Routes** (directed
#' links, optionally gated by a condition function). Execution is always
#' sequential: the output of one Station becomes the input of the next.
#'
#' Stations whose results have already been computed can be retrieved from an
#' internal cache instead of being re-executed, which is useful when iterating
#' on later parts of the pipeline without paying the cost (or latency) of
#' earlier LLM calls.
#'
#' A finished `Workflow` can be wrapped as a `WorkflowAgent` via
#' \code{$as_agent()}, making it composable with `LeadAgent` or embeddable as
#' a Station inside another `Workflow`.
#'
#' @export
Workflow <- R6::R6Class(
  "Workflow",
  cloneable = FALSE,

  # -- public -----------------------------------------------------------------
  public = list(

    #' @field name Workflow identifier.
    name = NULL,

    #' @field description Optional human-readable description.
    description = NULL,

    #' @field use_cache Whether to cache and reuse Station results.
    use_cache = NULL,

    #' @field cache Environment used as a hash-map for cached Station outputs.
    cache = NULL,

    #' @field run_history List of records from every \code{$run()} call.
    run_history = NULL,

    #' @field hitl_steps Integer vector of step numbers at which execution pauses
    #'   for human review. Set via \code{$set_hitl()}.
    hitl_steps = NULL,

    # -- initialize ------------------------------------------------------------

    #' @description Create a new `Workflow`.
    #'
    #' @param name `[character(1)]` Workflow name.
    #' @param description `[character(1)]` Optional description.
    #' @param use_cache `[logical(1)]` Enable result caching (default `TRUE`).
    initialize = function(name, description = NULL, use_cache = TRUE) {
      checkmate::assert_string(name)
      checkmate::assert_flag(use_cache)
      if (!is.null(description)) checkmate::assert_string(description)

      self$name        <- name
      self$description <- description
      self$use_cache   <- use_cache
      self$cache       <- new.env(hash = TRUE, parent = emptyenv())
      self$run_history <- list()
    },

    # -- add_station -----------------------------------------------------------

    #' @description Add a Station to the workflow.
    #'
    #' A Station is a named processing unit. Its `handler` can be:
    #' \itemize{
    #'   \item An `Agent` or `WorkflowAgent` - the Station calls
    #'         \code{handler$invoke(input)}.
    #'   \item A plain R `function(input)` - the Station calls
    #'         \code{handler(input)} and coerces the return value to
    #'         `character`.
    #' }
    #'
    #' @param name `[character(1)]` Unique Station name within this workflow.
    #' @param handler An `Agent`, `WorkflowAgent`, or `function`.
    #' @param description `[character(1)]` Optional human-readable description
    #'   (shown in \code{$visualize()}).
    #'
    #' @return Invisibly returns `self` for method chaining.
    add_station = function(name, handler, description = NULL) {
      checkmate::assert_string(name)
      if (!is.null(description)) checkmate::assert_string(description)

      is_agent    <- inherits(handler, "Agent") || inherits(handler, "WorkflowAgent")
      is_function <- is.function(handler)

      if (!is_agent && !is_function) {
        cli::cli_abort(c(
          "{.arg handler} must be an {.cls Agent}, {.cls WorkflowAgent}, or a {.cls function}.",
          "i" = "Received: {.cls {class(handler)[[1L]]}}."
        ))
      }

      if (name %in% names(private$.stations)) {
        cli::cli_abort("A Station named {.val {name}} already exists in workflow {.val {self$name}}.")
      }

      private$.stations[[name]] <- list(
        name        = name,
        handler     = handler,
        description = description
      )

      cli::cli_alert_success("Station {.val {name}} added.")
      invisible(self)
    },

    # -- add_route -------------------------------------------------------------

    #' @description Add a Route between two Stations.
    #'
    #' Routes define the execution order. An optional `condition` function
    #' receives the output of the `from` Station and must return `TRUE` or
    #' `FALSE`. Conditional routes are evaluated first (in insertion order);
    #' the first matching one is followed. If none match, the first
    #' unconditional route from that Station is used as a default.
    #'
    #' @param from `[character(1)]` Name of the source Station.
    #' @param to `[character(1)]` Name of the destination Station.
    #' @param condition `[function | NULL]` A function \code{function(output)}
    #'   returning a single logical value. `NULL` means "always follow this
    #'   route" (i.e., unconditional).
    #'
    #' @return Invisibly returns `self` for method chaining.
    add_route = function(from, to, condition = NULL) {
      checkmate::assert_string(from)
      checkmate::assert_string(to)

      if (!from %in% names(private$.stations)) {
        cli::cli_abort("Station {.val {from}} not found. Add it first with {.fn add_station}.")
      }
      if (!to %in% names(private$.stations)) {
        cli::cli_abort("Station {.val {to}} not found. Add it first with {.fn add_station}.")
      }
      if (!is.null(condition) && !is.function(condition)) {
        cli::cli_abort(
          "{.arg condition} must be a {.cls function} returning {.val TRUE}/{.val FALSE}, or {.val NULL}."
        )
      }

      private$.routes <- c(
        private$.routes,
        list(list(from = from, to = to, condition = condition))
      )

      cli::cli_alert_success("Route {.val {from}} -> {.val {to}} registered.")
      invisible(self)
    },

    # -- set_entry -------------------------------------------------------------

    #' @description Set the entry Station where execution begins.
    #'
    #' If not called, \code{$run()} defaults to the first Station added.
    #'
    #' @param station_name `[character(1)]` Name of the entry Station.
    #'
    #' @return Invisibly returns `self` for method chaining.
    set_entry = function(station_name) {
      checkmate::assert_string(station_name)

      if (!station_name %in% names(private$.stations)) {
        cli::cli_abort("Station {.val {station_name}} not found. Add it with {.fn add_station}.")
      }

      private$.entry <- station_name
      cli::cli_alert_success("Entry Station set to {.val {station_name}}.")
      invisible(self)
    },

    # -- run -------------------------------------------------------------------

    #' @description Execute the workflow sequentially.
    #'
    #' The `input` string is passed to the entry Station. Each Station's
    #' output becomes the next Station's input. Execution stops when a Station
    #' has no outgoing Route (or no Route whose condition evaluates to `TRUE`).
    #'
    #' When \code{use_cache = TRUE}, a Station whose (name, input) pair has
    #' been seen before returns the cached output without re-invoking the
    #' handler. Use \code{$clear_cache()} to force re-execution.
    #'
    #' @param input `[character(1)]` The initial prompt / payload.
    #'
    #' @return `[character(1)]` The output of the last Station executed.
    run = function(input) {
      checkmate::assert_string(input)

      if (length(private$.stations) == 0L) {
        cli::cli_abort("No Stations defined. Use {.fn add_station} first.")
      }

      entry <- if (!is.null(private$.entry)) {
        private$.entry
      } else {
        names(private$.stations)[[1L]]
      }

      if (is.null(private$.entry)) {
        cli::cli_alert_info(
          "No entry Station set - defaulting to first Station: {.val {entry}}."
        )
      }

      cli::cli_rule(left = glue::glue("Workflow: {self$name}"))

      current       <- entry
      current_input <- input
      trace         <- list()
      steps_taken   <- 0L
      max_steps     <- 500L
      result        <- NULL

      repeat {
        steps_taken <- steps_taken + 1L

        if (steps_taken > max_steps) {
          cli::cli_abort(
            "Workflow exceeded {max_steps} steps. Possible cycle in Routes."
          )
        }

        station   <- private$.stations[[current]]
        cache_key <- private$.cache_key(current, current_input)

        if (self$use_cache && exists(cache_key, envir = self$cache, inherits = FALSE)) {
          cli::cli_alert_info("[cache] Station {.val {current}}.")
          result <- get(cache_key, envir = self$cache, inherits = FALSE)
        } else {
          cli::cli_text("  {cli::col_blue('->')} Station {.val {current}}")
          result <- private$.invoke_handler(station$handler, current_input)

          if (!is.null(self$hitl_steps) && steps_taken %in% self$hitl_steps) {
            result <- private$.human_confirm(steps_taken, current, current_input, result)
          }

          if (self$use_cache) {
            assign(cache_key, result, envir = self$cache)
          }
        }

        trace[[length(trace) + 1L]] <- list(
          step    = steps_taken,
          station = current,
          input   = current_input,
          output  = result
        )

        next_station <- private$.get_next_station(current, result)

        if (is.null(next_station)) break

        current       <- next_station
        current_input <- result
      }

      cli::cli_alert_success(
        "Workflow {.val {self$name}} completed in {steps_taken} step(s)."
      )

      self$run_history[[length(self$run_history) + 1L]] <- list(
        input  = input,
        output = result,
        steps  = steps_taken,
        trace  = trace
      )

      result
    },

    # -- set_hitl --------------------------------------------------------------

    #' @description Set Human-In-The-Loop (HITL) pause points.
    #'
    #' When execution reaches a step whose number is listed in `steps`, it
    #' pauses and presents the human with three choices:
    #' \enumerate{
    #'   \item Continue with the Station's original output.
    #'   \item Edit the output manually before the next Station receives it.
    #'   \item Stop the workflow immediately (raises an error).
    #' }
    #' HITL only fires on fresh Station executions - cache hits are skipped.
    #' Steps are numbered from 1 in execution order, matching the step counter
    #' shown in \code{$run()} output. You can set multiple steps at once:
    #' \code{wf$set_hitl(c(1, 3))}.
    #'
    #' @param steps `[integerish]` One or more step numbers (>= 1).
    #'
    #' @return Invisibly returns `self` for method chaining.
    set_hitl = function(steps) {
      checkmate::assert_integerish(steps, lower = 1L, any.missing = FALSE)
      self$hitl_steps <- unique(as.integer(steps))
      cli::cli_alert_success(
        "HITL enabled at step(s): {.val {toString(self$hitl_steps)}}."
      )
      invisible(self)
    },

    # -- clear_cache -----------------------------------------------------------

    #' @description Remove all cached Station results.
    #'
    #' @return Invisibly returns `self`.
    clear_cache = function() {
      cached <- ls(self$cache)
      if (length(cached) > 0L) rm(list = cached, envir = self$cache)
      cli::cli_alert_success("Cache cleared for workflow {.val {self$name}}.")
      invisible(self)
    },

    # -- as_agent --------------------------------------------------------------

    #' @description Wrap this Workflow as a `WorkflowAgent`.
    #'
    #' The returned `WorkflowAgent` exposes \code{$invoke(prompt)} and holds an
    #' `agent_id`, making it compatible with `LeadAgent$register_agents()` and
    #' usable as a Station handler inside another `Workflow`.
    #'
    #' @param name `[character(1)]` Name for the `WorkflowAgent`. Defaults to
    #'   \code{"\{workflow name\} (agent)"}.
    #' @param instruction `[character(1)]` Instruction string describing the
    #'   agent's role. Used by `LeadAgent` for task-agent matching.
    #'
    #' @return A `WorkflowAgent` object.
    as_agent = function(name = NULL, instruction = NULL) {
      agent_name <- if (!is.null(name)) {
        name
      } else {
        paste0(self$name, " (agent)")
      }

      agent_instruction <- if (!is.null(instruction)) {
        instruction
      } else {
        desc_part <- if (!is.null(self$description) && nchar(self$description) > 0L) {
          paste0(" ", self$description, ".")
        } else {
          ""
        }
        paste0(
          "You are a workflow agent named '", self$name, "'.",
          desc_part,
          " When invoked with a prompt, you run a sequential pipeline of",
          " specialized Stations and return the final result."
        )
      }

      wa <- WorkflowAgent$new(
        name        = agent_name,
        instruction = agent_instruction,
        workflow    = self
      )

      cli::cli_alert_success(
        "Workflow {.val {self$name}} wrapped as agent {.val {agent_name}}."
      )

      wa
    },

    # -- visualize -------------------------------------------------------------

    #' @description Render the workflow as a directed graph via DiagrammeR.
    #'
    #' Stations are shown as rounded boxes. Conditional Routes are shown as
    #' dashed arrows labelled "cond". The entry Station is marked with a filled
    #' circle labelled "START".
    #'
    #' @return A `DiagrammeR` / `htmlwidget` object.
    visualize = function() {
      if (length(private$.stations) == 0L) {
        cli::cli_abort("Nothing to visualize - no Stations have been added.")
      }

      nodes <- vapply(names(private$.stations), function(n) {
        s            <- private$.stations[[n]]
        handler_type <- if (inherits(s$handler, c("Agent", "WorkflowAgent"))) {
          class(s$handler)[[1L]]
        } else {
          "Function"
        }
        bot_label <- if (!is.null(s$description)) s$description else handler_type
        glue::glue(
          '  "{n}" [label="{n}\\n[{bot_label}]", shape=box,',
          ' style="filled,rounded", fillcolor="#AED6F1"]'
        )
      }, character(1L))

      entry_name <- if (!is.null(private$.entry)) {
        private$.entry
      } else {
        names(private$.stations)[[1L]]
      }

      entry_def <- c(
        '  "START" [label="START", shape=circle, style=filled, fillcolor="#82E0AA", width=0.5]',
        glue::glue('  "START" -> "{entry_name}"')
      )

      routes <- vapply(private$.routes, function(r) {
        attrs <- if (!is.null(r$condition)) {
          ' [label="  cond", style=dashed]'
        } else {
          ""
        }
        glue::glue('  "{r$from}" -> "{r$to}"{attrs}')
      }, character(1L))

      dot <- paste0(
        "digraph workflow {\n",
        '  graph [rankdir=TB, label="', self$name,
        '", labelloc=t, fontsize=18, fontname="Helvetica"]\n',
        "  node [fontname=\"Helvetica\", fontsize=12]\n",
        "  edge [fontname=\"Helvetica\", fontsize=10]\n",
        paste(nodes,     collapse = "\n"), "\n",
        paste(entry_def, collapse = "\n"), "\n",
        if (length(routes) > 0L) paste(routes, collapse = "\n") else "",
        "\n}"
      )

      DiagrammeR::grViz(dot)
    }
  ),

  # -- private ----------------------------------------------------------------
  private = list(
    .stations = list(),
    .routes   = list(),
    .entry    = NULL,

    # Resolve the next Station given the current one and its output.
    # Conditional Routes are tried first (in insertion order); the first
    # whose condition returns TRUE wins. If none match, the first
    # unconditional Route is used as default. Returns NULL if the workflow
    # should stop.
    .get_next_station = function(current, result) {
      from_here <- Filter(function(r) r$from == current, private$.routes)

      if (length(from_here) == 0L) return(NULL)

      cond_routes   <- Filter(function(r) !is.null(r$condition), from_here)
      uncond_routes <- Filter(function(r)  is.null(r$condition), from_here)

      for (route in cond_routes) {
        ok <- tryCatch(
          isTRUE(route$condition(result)),
          error = function(e) {
            cli::cli_alert_warning(
              "Condition on route {.val {route$from}} -> {.val {route$to}} errored: {e$message}"
            )
            FALSE
          }
        )
        if (ok) return(route$to)
      }

      if (length(uncond_routes) > 0L) return(uncond_routes[[1L]]$to)

      NULL
    },

    # Dispatch a handler call: Agent/WorkflowAgent use $invoke(); plain
    # functions are called directly and their output coerced to character.
    .invoke_handler = function(handler, input) {
      if (inherits(handler, c("Agent", "WorkflowAgent"))) {
        handler$invoke(input)
      } else {
        out <- handler(input)
        if (!is.character(out)) as.character(out) else out
      }
    },

    # Pause execution, show the station's input and output, then ask the human
    # what to do. Returns the result to continue with (original or edited).
    .human_confirm = function(step_index, station_name, input, result) {
      cli::cli_rule(left = glue::glue("HITL - Step {step_index}"))
      cli::cli_text("Station: {.strong {station_name}}")
      cli::cli_alert_info("Input:")
      cli::cli_verbatim(input)
      cli::cli_alert_info("Output:")
      cli::cli_verbatim(result)

      cli::cli_text(cli::cli_ul(c(
        "[1] Continue with this output",
        "[2] Edit the output",
        "[3] Stop the workflow"
      )))

      repeat {
        answer <- readline("Your choice [1/2/3]: ")
        if (nzchar(answer) && answer %in% c("1", "2", "3")) break
        cli::cli_alert_warning("Invalid input. Please enter 1, 2, or 3.")
      }

      if (answer == "2") {
        new_result <- readline("(->) Enter edited output: ")
        cli::cli_alert_success("Output updated.")
        return(new_result)
      } else if (answer == "3") {
        cli::cli_alert_danger("Workflow stopped by user at step {step_index}.")
        cli::cli_abort("HITL: Execution stopped by user.")
      } else {
        cli::cli_alert_success("Continuing with original output.")
        return(result)
      }
    },

    # Build a deterministic cache key from a Station name and its input.
    # The fixed separator is unlikely to appear in normal station names or prompts.
    .cache_key = function(station_name, input) {
      paste0(station_name, "|||", substr(input, 1L, 1024L))
    }
  )
)


# ==============================================================================

#' @title WorkflowAgent
#'
#' @description
#' A lightweight, Agent-compatible wrapper around a `Workflow`. Created via
#' \code{Workflow$as_agent()}.
#'
#' `WorkflowAgent` exposes the same interface that `LeadAgent` expects from
#' any agent (\code{name}, \code{instruction}, \code{agent_id},
#' \code{$invoke()}), so it can be:
#' \itemize{
#'   \item Registered with \code{LeadAgent$register_agents()}.
#'   \item Used as a Station handler inside another `Workflow`.
#' }
#'
#' Do not instantiate `WorkflowAgent` directly - use \code{Workflow$as_agent()}.
#'
#' @export
WorkflowAgent <- R6::R6Class(
  "WorkflowAgent",
  cloneable = FALSE,

  public = list(

    #' @field name Agent name (visible to `LeadAgent` for task matching).
    name = NULL,

    #' @field instruction System instruction describing the agent's role.
    instruction = NULL,

    #' @field agent_id Unique identifier (UUID).
    agent_id = NULL,

    #' @field workflow The underlying `Workflow` object.
    workflow = NULL,

    #' @field messages Conversation history as a list of
    #'   \code{list(role, content)} entries.
    messages = NULL,

    #' @description Create a new `WorkflowAgent`. Prefer \code{Workflow$as_agent()}.
    #'
    #' @param name `[character(1)]` Agent name.
    #' @param instruction `[character(1)]` Instruction / system prompt.
    #' @param workflow A `Workflow` object.
    initialize = function(name, instruction, workflow) {
      checkmate::assert_string(name)
      checkmate::assert_string(instruction)

      if (!inherits(workflow, "Workflow")) {
        cli::cli_abort("{.arg workflow} must be a {.cls Workflow} object.")
      }

      self$name        <- name
      self$instruction <- instruction
      self$agent_id    <- uuid::UUIDgenerate()
      self$workflow    <- workflow
      self$messages    <- list()
    },

    #' @description Run the underlying workflow with `prompt` as input.
    #'
    #' @param prompt `[character(1)]` The user prompt / input payload.
    #'
    #' @return `[character(1)]` The final output of the workflow.
    invoke = function(prompt) {
      checkmate::assert_string(prompt)

      self$messages <- c(
        self$messages,
        list(list(role = "user", content = prompt))
      )

      result <- self$workflow$run(prompt)

      self$messages <- c(
        self$messages,
        list(list(role = "assistant", content = result))
      )

      result
    },

    #' @description Clear the conversation history stored in \code{$messages}.
    #'
    #' @return Invisibly returns `self`.
    reset_conversation_history = function() {
      self$messages <- list()
      invisible(self)
    }
  )
)
