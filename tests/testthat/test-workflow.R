library(testthat)
library(mini007)

# ── Helpers ───────────────────────────────────────────────────────────────────

# Minimal R6 mock that passes inherits(x, "Agent") check and records calls.
MockAgent <- R6::R6Class(
  classname = "Agent",
  public = list(
    call_count = 0L,
    response   = NULL,
    initialize = function(response = "mock output") {
      self$response <- response
    },
    invoke = function(input) {
      self$call_count <- self$call_count + 1L
      self$response
    }
  )
)

# ── Workflow: initialization ──────────────────────────────────────────────────

test_that("Workflow initializes with correct defaults", {
  wf <- Workflow$new("MyFlow")
  expect_equal(wf$name, "MyFlow")
  expect_null(wf$description)
  expect_true(wf$use_cache)
  expect_null(wf$hitl_steps)
  expect_length(wf$run_history, 0L)
  expect_true(is.environment(wf$cache))
})

test_that("Workflow initializes with description and use_cache = FALSE", {
  wf <- Workflow$new("F", description = "A test workflow", use_cache = FALSE)
  expect_equal(wf$description, "A test workflow")
  expect_false(wf$use_cache)
})

test_that("Workflow$new errors on non-string name", {
  expect_error(Workflow$new(123))
  expect_error(Workflow$new(NULL))
})

test_that("Workflow$new errors on non-logical use_cache", {
  expect_error(Workflow$new("W", use_cache = "yes"))
  expect_error(Workflow$new("W", use_cache = 1L))
})

test_that("Workflow$new errors on non-string description", {
  expect_error(Workflow$new("W", description = 123))
  expect_error(Workflow$new("W", description = TRUE))
})

# ── add_station ───────────────────────────────────────────────────────────────

test_that("add_station accepts an Agent handler", {
  wf <- Workflow$new("W")
  expect_no_error(wf$add_station("s1", MockAgent$new()))
})

test_that("add_station accepts a function handler", {
  wf <- Workflow$new("W")
  expect_no_error(wf$add_station("s1", toupper))
})

test_that("add_station returns self invisibly for chaining", {
  wf     <- Workflow$new("W")
  result <- wf$add_station("s1", toupper)
  expect_identical(result, wf)
})

test_that("add_station errors on duplicate station name", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_error(wf$add_station("s1", tolower), "already exists")
})

test_that("add_station errors when handler is neither Agent nor function", {
  wf <- Workflow$new("W")
  expect_error(wf$add_station("s1", 42L),    "handler")
  expect_error(wf$add_station("s1", list()), "handler")
  expect_error(wf$add_station("s1", TRUE),   "handler")
})

test_that("add_station errors on non-string name", {
  wf <- Workflow$new("W")
  expect_error(wf$add_station(123, toupper))
})

test_that("add_station accepts an optional description string", {
  wf <- Workflow$new("W")
  expect_no_error(wf$add_station("s1", toupper, description = "Uppercase step"))
})

test_that("add_station errors on non-string description", {
  wf <- Workflow$new("W")
  expect_error(wf$add_station("s1", toupper, description = 99))
})

# ── add_route ─────────────────────────────────────────────────────────────────

test_that("add_route registers a route and returns self invisibly", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  result <- wf$add_route("s1", "s2")
  expect_identical(result, wf)
})

test_that("add_route errors when from station does not exist", {
  wf <- Workflow$new("W")
  wf$add_station("s2", tolower)
  expect_error(wf$add_route("s1", "s2"), "not found")
})

test_that("add_route errors when to station does not exist", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_error(wf$add_route("s1", "s2"), "not found")
})

test_that("add_route accepts a valid condition function", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  expect_no_error(wf$add_route("s1", "s2", condition = function(x) nchar(x) > 5))
})

test_that("add_route errors when condition is not NULL and not a function", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  expect_error(wf$add_route("s1", "s2", condition = TRUE),      "condition")
  expect_error(wf$add_route("s1", "s2", condition = "always"),  "condition")
  expect_error(wf$add_route("s1", "s2", condition = 1L),        "condition")
})

test_that("add_route allows multiple routes from the same station", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  wf$add_station("s3", function(x) x)
  expect_no_error({
    wf$add_route("s1", "s2", condition = function(x) TRUE)
    wf$add_route("s1", "s3")
  })
})

# ── set_entry ─────────────────────────────────────────────────────────────────

test_that("set_entry sets the entry station and returns self invisibly", {
  wf     <- Workflow$new("W")
  wf$add_station("s1", toupper)
  result <- wf$set_entry("s1")
  expect_identical(result, wf)
})

test_that("set_entry errors when station not found", {
  wf <- Workflow$new("W")
  expect_error(wf$set_entry("missing"), "not found")
})

# ── run: basic execution ──────────────────────────────────────────────────────

test_that("run errors when no stations are defined", {
  wf <- Workflow$new("W")
  expect_error(wf$run("hello"), "No Stations")
})

test_that("run errors on non-string input", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_error(wf$run(123))
  expect_error(wf$run(NULL))
  expect_error(wf$run(c("a", "b")))
})

test_that("run executes a single function station and returns its output", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_equal(wf$run("hello"), "HELLO")
})

test_that("run passes each station's output as the next station's input", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", function(x) paste("got:", x))
  wf$add_route("s1", "s2")
  expect_equal(wf$run("hello"), "got: HELLO")
})

test_that("run executes an Agent station via invoke()", {
  agent <- MockAgent$new("agent reply")
  wf    <- Workflow$new("W")
  wf$add_station("s1", agent)
  expect_equal(wf$run("anything"), "agent reply")
  expect_equal(agent$call_count, 1L)
})

test_that("run coerces non-character function output to character", {
  wf <- Workflow$new("W")
  wf$add_station("s1", function(x) 42L)
  result <- wf$run("input")
  expect_type(result, "character")
  expect_equal(result, "42")
})

test_that("run uses the explicitly set entry station", {
  wf <- Workflow$new("W")
  wf$add_station("s1", function(x) paste("s1:", x))
  wf$add_station("s2", function(x) paste("s2:", x))
  wf$set_entry("s2")
  expect_equal(wf$run("in"), "s2: in")
})

test_that("run defaults to first added station when no entry is set", {
  wf <- Workflow$new("W")
  wf$add_station("first",  function(x) paste("FIRST:",  x))
  wf$add_station("second", function(x) paste("SECOND:", x))
  expect_equal(wf$run("x"), "FIRST: x")
})

test_that("run stops at station with no outgoing route", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  # No route from s1 — workflow ends after s1
  expect_equal(wf$run("hello"), "HELLO")
})

test_that("run handles a three-station chain correctly", {
  wf <- Workflow$new("W")
  wf$add_station("a", toupper)
  wf$add_station("b", function(x) paste0("[", x, "]"))
  wf$add_station("c", function(x) paste("done:", x))
  wf$add_route("a", "b")
  wf$add_route("b", "c")
  expect_equal(wf$run("hi"), "done: [HI]")
})

# ── run: history and trace ────────────────────────────────────────────────────

test_that("run appends a record to run_history after each call", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$run("hello")
  wf$run("world")
  expect_length(wf$run_history, 2L)
  expect_equal(wf$run_history[[1L]]$input,  "hello")
  expect_equal(wf$run_history[[1L]]$output, "HELLO")
  expect_equal(wf$run_history[[2L]]$input,  "world")
  expect_equal(wf$run_history[[2L]]$output, "WORLD")
})

test_that("run history trace contains per-step station and I/O info", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  wf$add_route("s1", "s2")
  wf$run("Hello")
  trace <- wf$run_history[[1L]]$trace
  expect_length(trace, 2L)
  expect_equal(trace[[1L]]$step,    1L)
  expect_equal(trace[[1L]]$station, "s1")
  expect_equal(trace[[1L]]$input,   "Hello")
  expect_equal(trace[[1L]]$output,  "HELLO")
  expect_equal(trace[[2L]]$step,    2L)
  expect_equal(trace[[2L]]$station, "s2")
  expect_equal(trace[[2L]]$input,   "HELLO")
  expect_equal(trace[[2L]]$output,  "hello")
})

test_that("run history steps count is correct", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  wf$add_station("s3", function(x) x)
  wf$add_route("s1", "s2")
  wf$add_route("s2", "s3")
  wf$run("hi")
  expect_equal(wf$run_history[[1L]]$steps, 3L)
})

# ── run: caching ──────────────────────────────────────────────────────────────

test_that("run caches output so repeated identical runs skip re-execution", {
  calls <- 0L
  wf <- Workflow$new("W", use_cache = TRUE)
  wf$add_station("s1", function(x) { calls <<- calls + 1L; toupper(x) })
  wf$run("hello")
  wf$run("hello")
  expect_equal(calls, 1L)
})

test_that("run re-executes when input differs even with cache enabled", {
  calls <- 0L
  wf <- Workflow$new("W", use_cache = TRUE)
  wf$add_station("s1", function(x) { calls <<- calls + 1L; toupper(x) })
  wf$run("hello")
  wf$run("world")
  expect_equal(calls, 2L)
})

test_that("run with use_cache = FALSE always re-executes", {
  calls <- 0L
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) { calls <<- calls + 1L; toupper(x) })
  wf$run("hello")
  wf$run("hello")
  expect_equal(calls, 2L)
})

test_that("cached run still returns the correct output", {
  wf <- Workflow$new("W", use_cache = TRUE)
  wf$add_station("s1", toupper)
  wf$run("hello")
  expect_equal(wf$run("hello"), "HELLO")
})

# ── clear_cache ───────────────────────────────────────────────────────────────

test_that("clear_cache forces re-execution on the next run", {
  calls <- 0L
  wf <- Workflow$new("W", use_cache = TRUE)
  wf$add_station("s1", function(x) { calls <<- calls + 1L; toupper(x) })
  wf$run("hello")
  wf$clear_cache()
  wf$run("hello")
  expect_equal(calls, 2L)
})

test_that("clear_cache returns self invisibly", {
  wf     <- Workflow$new("W")
  result <- wf$clear_cache()
  expect_identical(result, wf)
})

test_that("clear_cache is safe when cache is already empty", {
  wf <- Workflow$new("W")
  expect_no_error(wf$clear_cache())
})

# ── conditional routes ────────────────────────────────────────────────────────

test_that("matching conditional route is followed", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "long enough string")
  wf$add_station("s2", function(x) paste("LONG:", x))
  wf$add_station("s3", function(x) paste("SHORT:", x))
  wf$add_route("s1", "s2", condition = function(x) nchar(x) >= 10)
  wf$add_route("s1", "s3")
  expect_equal(wf$run("go"), "LONG: long enough string")
})

test_that("unconditional fallback route is used when no condition matches", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "hi")
  wf$add_station("s2", function(x) paste("LONG:", x))
  wf$add_station("s3", function(x) paste("SHORT:", x))
  wf$add_route("s1", "s2", condition = function(x) nchar(x) >= 100)
  wf$add_route("s1", "s3")
  expect_equal(wf$run("go"), "SHORT: hi")
})

test_that("first matching conditional route wins when multiple conditions are true", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "abc")
  wf$add_station("s2", function(x) "route-A")
  wf$add_station("s3", function(x) "route-B")
  wf$add_route("s1", "s2", condition = function(x) TRUE)
  wf$add_route("s1", "s3", condition = function(x) TRUE)
  expect_equal(wf$run("go"), "route-A")
})

test_that("erroring condition is treated as FALSE without crashing", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "out")
  wf$add_station("s2", function(x) paste("next:", x))
  wf$add_route("s1", "s2", condition = function(x) stop("boom"))
  # Condition errors → treated as FALSE, no unconditional fallback → workflow stops
  expect_equal(wf$run("in"), "out")
})

test_that("workflow stops when no outgoing route matches", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "short")
  wf$add_station("s2", function(x) "never reached")
  wf$add_route("s1", "s2", condition = function(x) nchar(x) > 100)
  # No unconditional fallback
  expect_equal(wf$run("go"), "short")
})

# ── set_hitl ─────────────────────────────────────────────────────────────────

test_that("set_hitl sets hitl_steps and returns self invisibly", {
  wf     <- Workflow$new("W")
  result <- wf$set_hitl(1L)
  expect_equal(wf$hitl_steps, 1L)
  expect_identical(result, wf)
})

test_that("set_hitl accepts multiple steps and deduplicates", {
  wf <- Workflow$new("W")
  wf$set_hitl(c(1L, 2L, 2L, 3L))
  expect_equal(wf$hitl_steps, c(1L, 2L, 3L))
})

test_that("set_hitl coerces numeric to integer", {
  wf <- Workflow$new("W")
  wf$set_hitl(c(1, 2))
  expect_type(wf$hitl_steps, "integer")
})

test_that("set_hitl errors on non-integerish steps", {
  wf <- Workflow$new("W")
  expect_error(wf$set_hitl("one"))
  expect_error(wf$set_hitl(list(1)))
})

test_that("set_hitl errors on steps lower than 1", {
  wf <- Workflow$new("W")
  expect_error(wf$set_hitl(0L))
  expect_error(wf$set_hitl(-1L))
})

test_that("HITL choice 1 continues with original station output", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "original")
  wf$set_hitl(1L)
  local_mocked_bindings(
    readline = function(prompt) "1",
    .package = "base"
  )
  expect_equal(wf$run("input"), "original")
})

test_that("HITL choice 2 replaces station output with edited text", {
  calls <- 0L
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "original")
  wf$set_hitl(1L)
  local_mocked_bindings(
    readline = function(prompt) {
      calls <<- calls + 1L
      if (calls == 1L) "2" else "edited output"
    },
    .package = "base"
  )
  expect_equal(wf$run("input"), "edited output")
})

test_that("HITL choice 3 aborts the workflow with an error", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) "output")
  wf$set_hitl(1L)
  local_mocked_bindings(
    readline = function(prompt) "3",
    .package = "base"
  )
  expect_error(wf$run("input"), "[Ss]topped by user")
})

test_that("HITL fires only on the specified step, not others", {
  hitl_fired <- FALSE
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) paste("A:", x))
  wf$add_station("s2", function(x) paste("B:", x))
  wf$add_route("s1", "s2")
  wf$set_hitl(2L)  # only step 2
  local_mocked_bindings(
    readline = function(prompt) { hitl_fired <<- TRUE; "1" },
    .package = "base"
  )
  result <- wf$run("in")
  expect_true(hitl_fired)
  expect_equal(result, "B: A: in")
})

test_that("HITL is skipped on cache hit", {
  hitl_called <- FALSE
  wf <- Workflow$new("W", use_cache = TRUE)
  wf$add_station("s1", function(x) "out")
  wf$set_hitl(1L)
  # First run — HITL fires
  local_mocked_bindings(
    readline = function(prompt) "1",
    .package = "base"
  )
  wf$run("hello")
  # Second run — cache hit, HITL must NOT fire
  local_mocked_bindings(
    readline = function(prompt) { hitl_called <<- TRUE; "1" },
    .package = "base"
  )
  wf$run("hello")
  expect_false(hitl_called)
})

# ── as_agent ─────────────────────────────────────────────────────────────────

test_that("as_agent returns a WorkflowAgent", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_s3_class(wf$as_agent(), "WorkflowAgent")
})

test_that("as_agent defaults name to '<workflow name> (agent)'", {
  wf <- Workflow$new("MyFlow")
  wf$add_station("s1", toupper)
  expect_equal(wf$as_agent()$name, "MyFlow (agent)")
})

test_that("as_agent uses a custom name when provided", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_equal(wf$as_agent(name = "CustomAgent")$name, "CustomAgent")
})

test_that("as_agent assigns a non-null character UUID", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  expect_type(wa$agent_id, "character")
  expect_false(is.null(wa$agent_id))
  expect_gt(nchar(wa$agent_id), 0L)
})

test_that("as_agent keeps a reference to the underlying workflow", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  expect_identical(wa$workflow, wf)
})

test_that("as_agent uses a custom instruction when provided", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent(instruction = "Do the thing.")
  expect_equal(wa$instruction, "Do the thing.")
})

test_that("as_agent embeds workflow description in default instruction", {
  wf <- Workflow$new("W", description = "does something special")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  expect_true(grepl("does something special", wa$instruction))
})

test_that("as_agent default instruction includes the workflow name", {
  wf <- Workflow$new("UniqueFlowName")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  expect_true(grepl("UniqueFlowName", wa$instruction))
})

test_that("two as_agent() calls produce distinct agent_ids", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa1 <- wf$as_agent()
  wa2 <- wf$as_agent()
  expect_false(identical(wa1$agent_id, wa2$agent_id))
})

# ── WorkflowAgent ─────────────────────────────────────────────────────────────

test_that("WorkflowAgent initializes empty messages list", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  expect_length(wa$messages, 0L)
})

test_that("WorkflowAgent$new errors when workflow is not a Workflow object", {
  expect_error(
    WorkflowAgent$new("A", "I", workflow = list()),
    "Workflow"
  )
})

test_that("WorkflowAgent$new errors on non-string name", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_error(WorkflowAgent$new(123, "I", wf))
})

test_that("WorkflowAgent$new errors on non-string instruction", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  expect_error(WorkflowAgent$new("A", 123, wf))
})

test_that("WorkflowAgent$invoke runs the workflow and returns its output", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  expect_equal(wa$invoke("hello"), "HELLO")
})

test_that("WorkflowAgent$invoke appends one user and one assistant message", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  wa$invoke("hello")
  expect_length(wa$messages, 2L)
  expect_equal(wa$messages[[1L]]$role,    "user")
  expect_equal(wa$messages[[1L]]$content, "hello")
  expect_equal(wa$messages[[2L]]$role,    "assistant")
  expect_equal(wa$messages[[2L]]$content, "HELLO")
})

test_that("WorkflowAgent$invoke accumulates messages across multiple calls", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  wa$invoke("hello")
  wa$invoke("world")
  expect_length(wa$messages, 4L)
  expect_equal(wa$messages[[3L]]$content, "world")
  expect_equal(wa$messages[[4L]]$content, "WORLD")
})

test_that("WorkflowAgent$reset_conversation_history clears all messages", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa <- wf$as_agent()
  wa$invoke("hello")
  wa$reset_conversation_history()
  expect_length(wa$messages, 0L)
})

test_that("WorkflowAgent$reset_conversation_history returns self invisibly", {
  wf     <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wa     <- wf$as_agent()
  result <- wa$reset_conversation_history()
  expect_identical(result, wa)
})

test_that("WorkflowAgent used as a station handler inside another Workflow", {
  inner_wf <- Workflow$new("inner")
  inner_wf$add_station("s1", toupper)
  inner_agent <- inner_wf$as_agent()

  outer_wf <- Workflow$new("outer")
  outer_wf$add_station("step1", inner_agent)
  expect_equal(outer_wf$run("hello"), "HELLO")
})

# ── visualize ─────────────────────────────────────────────────────────────────

test_that("visualize errors when no stations are defined", {
  wf <- Workflow$new("W")
  expect_error(wf$visualize(), "Nothing to visualize")
})

test_that("visualize returns an htmlwidget / grViz object", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  g <- wf$visualize()
  expect_true(inherits(g, "htmlwidget") || inherits(g, "grViz"))
})

test_that("visualize DOT output contains all station names", {
  wf <- Workflow$new("W")
  wf$add_station("alpha", toupper)
  wf$add_station("beta",  tolower)
  wf$add_route("alpha", "beta")
  g   <- wf$visualize()
  dot <- g$x$diagram
  expect_true(grepl("alpha", dot))
  expect_true(grepl("beta",  dot))
})

test_that("visualize DOT output contains a START node", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  g   <- wf$visualize()
  dot <- g$x$diagram
  expect_true(grepl("START", dot))
})

test_that("visualize marks conditional routes as dashed", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  wf$add_route("s1", "s2", condition = function(x) TRUE)
  g   <- wf$visualize()
  dot <- g$x$diagram
  expect_true(grepl("dashed", dot))
})

test_that("visualize unconditional routes have no dashed style", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  wf$add_route("s1", "s2")
  g   <- wf$visualize()
  dot <- g$x$diagram
  expect_false(grepl("dashed", dot))
})

test_that("visualize includes the workflow name as graph label", {
  wf <- Workflow$new("SpecialFlowName")
  wf$add_station("s1", toupper)
  g   <- wf$visualize()
  dot <- g$x$diagram
  expect_true(grepl("SpecialFlowName", dot))
})

test_that("visualize uses explicit entry station for START arrow", {
  wf <- Workflow$new("W")
  wf$add_station("s1", toupper)
  wf$add_station("s2", tolower)
  wf$set_entry("s2")
  g   <- wf$visualize()
  dot <- g$x$diagram
  expect_true(grepl('START.*->.*"s2"', dot) || grepl('"START".*->.*"s2"', dot))
})

# ── method chaining ───────────────────────────────────────────────────────────

test_that("full method-chaining pipeline works end-to-end", {
  result <- Workflow$new("Chain")$
    add_station("s1", toupper)$
    add_station("s2", function(x) paste0("[", x, "]"))$
    add_route("s1", "s2")$
    run("hello")
  expect_equal(result, "[HELLO]")
})
