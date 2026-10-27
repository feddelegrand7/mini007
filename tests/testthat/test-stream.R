library(testthat)
library(mini007)

# ── Helpers ───────────────────────────────────────────────────────────────────

providerclass <- setClass(
  "Provider",
  slots = c(
    name = "character",
    model  = "character"
  ))

provider <- new("Provider", name = "dummy", model = "v0")

# Mock of an ellmer Chat that supports $stream(stream = "content"). Each call
# yields the queued chunks (character strings become ContentText; ellmer
# Content objects are yielded as-is) and, like ellmer, only records the
# user/assistant turns once the stream has been fully consumed.
StreamingChat <- R6::R6Class(
  "Chat",
  public = list(
    system_prompt = NULL,
    turns = list(),
    tools = list(),
    provider = provider,
    chunks = NULL,
    fail_after = NULL,
    stream_calls = 0L,
    chat_calls = 0L,

    initialize = function(chunks = list("Hello", ", ", "world")) {
      self$chunks <- chunks
    },

    chat = function(prompt) {
      self$chat_calls <- self$chat_calls + 1L
      "non-streamed"
    },

    stream = function(prompt, stream = c("text", "content")) {
      self$stream_calls <- self$stream_calls + 1L
      chunks <- self$chunks
      fail_after <- self$fail_after
      chat <- self
      coro::generator(function() {
        text <- character(0)
        for (i in seq_along(chunks)) {
          if (!is.null(fail_after) && i > fail_after) {
            stop("connection reset by peer")
          }
          chunk <- chunks[[i]]
          if (is.character(chunk)) {
            text <- c(text, chunk)
            chunk <- ellmer::ContentText(chunk)
          }
          coro::yield(chunk)
        }
        chat$turns <- c(chat$turns, list(
          ellmer::Turn("user", list(ellmer::ContentText(prompt))),
          ellmer::Turn("assistant", list(ellmer::ContentText(paste(text, collapse = ""))))
        ))
      })()
    },

    last_turn = function() {
      if (length(self$turns) == 0L) return(NULL)
      self$turns[[length(self$turns)]]
    },

    get_cost = function() 0.5,
    get_tokens = function() data.frame(tokens_total = 10),
    set_system_prompt = function(value) { self$system_prompt <- value },
    get_system_prompt = function() self$system_prompt,
    set_turns = function(turns) { self$turns <- turns },
    get_turns = function(include_system_prompt = FALSE) {
      if (!include_system_prompt) return(self$turns)
      c(list(ellmer::Turn("system", list(ellmer::ContentText(self$system_prompt)))),
        self$turns)
    },
    register_tools = function(tools) { self$tools <- tools },
    get_provider = function() self$provider
  )
)

# Collects every event passed to it, in order.
event_collector <- function() {
  env <- new.env()
  env$events <- list()
  env$callback <- function(event) {
    env$events[[length(env$events) + 1L]] <- event
  }
  env$types <- function() vapply(env$events, function(e) e$type, character(1))
  env
}

streaming_agent <- function(name = "streamer", chunks = list("Hello", ", ", "world")) {
  Agent$new(name, "You stream.", StreamingChat$new(chunks))
}

# ── Agent ─────────────────────────────────────────────────────────────────────

test_that("Agent$invoke streams start, deltas and completion in order", {
  agent <- streaming_agent()
  col <- event_collector()

  res <- agent$invoke("hi", on_event = col$callback)

  expect_equal(res, "Hello, world")
  expect_equal(
    col$types(),
    c("agent_started", "text_delta", "text_delta", "text_delta", "agent_completed")
  )
  deltas <- vapply(col$events[2:4], function(e) e$text, character(1))
  expect_equal(paste(deltas, collapse = ""), res)
  expect_true(all(vapply(col$events, inherits, logical(1), "mini007_event")))
  expect_true(all(vapply(col$events, function(e) e$source, character(1)) == "streamer"))
  expect_equal(col$events[[5]]$text, res)
})

test_that("Agent$invoke streaming syncs messages and cost like invoke()", {
  agent <- streaming_agent()
  agent$invoke("hi", stream = TRUE) |> capture.output()

  expect_equal(agent$cost, 0.5)
  roles <- vapply(agent$messages, function(m) m$role, character(1))
  expect_equal(roles, c("system", "user", "assistant"))
  expect_equal(agent$messages[[3]]$content, "Hello, world")
})

test_that("stream = TRUE without a callback prints deltas to the console", {
  agent <- streaming_agent()
  expect_output(res <- withVisible(agent$invoke("hi", stream = TRUE)), "Hello, world")
  expect_equal(res$value, "Hello, world")
  expect_false(res$visible)
})

test_that("Workflow cache hits in a parallel group still emit station_started", {
  wf <- Workflow$new("W", use_cache = TRUE)
  wf$add_station("start", function(x) x)
  wf$add_station("a", function(x) paste0(x, "-a"))
  wf$add_station("b", function(x) paste0(x, "-b"))
  wf$add_parallel_group("start", c("a", "b"))
  mirai::daemons(1L)
  on.exit(mirai::daemons(0L), add = TRUE)
  wf$run("x")

  col <- event_collector()
  wf$run("x", on_event = col$callback)
  started <- Filter(function(e) e$type == "station_started" && isTRUE(e$data$parallel), col$events)
  completed <- Filter(function(e) e$type == "station_completed" && isTRUE(e$data$parallel), col$events)
  expect_length(started, 2L)
  expect_true(all(vapply(completed, function(e) e$data$from_cache, logical(1))))
})

test_that("non-streaming invoke() is unchanged and never calls $stream()", {
  agent <- streaming_agent()
  res <- agent$invoke("hi")
  expect_equal(res, "non-streamed")
  expect_equal(agent$llm_object$stream_calls, 0L)
  expect_equal(agent$llm_object$chat_calls, 1L)
})

test_that("tool requests and results become tool_call / tool_result events", {
  req <- ellmer::ContentToolRequest(id = "call_1", name = "get_weather",
                                     arguments = list(city = "Algiers"))
  res <- ellmer::ContentToolResult(value = "sunny", request = req)
  agent <- streaming_agent(chunks = list("Checking", req, res, "It is sunny"))
  col <- event_collector()

  agent$invoke("weather?", on_event = col$callback)

  types <- col$types()
  expect_equal(
    types,
    c("agent_started", "text_delta", "tool_call", "tool_result",
      "text_delta", "agent_completed")
  )
  call <- col$events[[3]]
  expect_equal(call$data$tool_name, "get_weather")
  expect_equal(call$data$arguments, list(city = "Algiers"))
  result <- col$events[[4]]
  expect_equal(result$data$tool_name, "get_weather")
  expect_equal(result$data$value, "sunny")
})

test_that("an error in on_event cancels the stream and keeps state consistent", {
  agent <- streaming_agent()
  seen <- 0L
  cancel_on_second_delta <- function(event) {
    if (event$type == "text_delta") {
      seen <<- seen + 1L
      if (seen == 2L) stop("user hit stop")
    }
  }

  # Check the top-level class: expect_error(class =) also matches parents,
  # which would hide a cancellation re-wrapped as a provider error.
  err <- tryCatch(
    agent$invoke("hi", on_event = cancel_on_second_delta),
    error = function(e) e
  )
  expect_s3_class(err, "mini007_stream_cancelled")
  expect_null(err$parent$parent)
  expect_equal(agent$cost, 0.5)
  expect_length(agent$messages, 1L)
  expect_equal(agent$messages[[1]]$role, "system")
})

test_that("a provider failure mid-stream gives the actionable Agent error", {
  agent <- streaming_agent()
  agent$llm_object$fail_after <- 1L
  expect_error(
    agent$invoke("hi", on_event = function(e) NULL),
    "could not get a response from the LLM provider"
  )
})

test_that("stream and on_event are validated", {
  agent <- streaming_agent()
  expect_error(agent$invoke("hi", stream = "yes"))
  expect_error(agent$invoke("hi", on_event = "not a function"))
})

# ── Workflow ──────────────────────────────────────────────────────────────────

test_that("Workflow$run streams station lifecycle and tagged agent deltas", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("write", streaming_agent("writer"))
  wf$add_station("shout", function(x) toupper(x))
  wf$add_route("write", "shout")
  col <- event_collector()

  res <- wf$run("go", on_event = col$callback)

  expect_equal(res, "HELLO, WORLD")
  expect_equal(
    col$types(),
    c("workflow_started",
      "station_started", "agent_started", "text_delta", "text_delta",
      "text_delta", "agent_completed", "station_completed",
      "station_started", "station_completed",
      "workflow_output")
  )

  delta <- col$events[[4]]
  expect_equal(delta$source, "writer")
  expect_equal(delta$data$station, "write")
  expect_equal(delta$data$step, 1L)

  expect_equal(col$events[[8]]$text, "Hello, world")
  expect_equal(col$events[[10]]$data$station, "shout")
  expect_equal(col$events[[11]]$text, "HELLO, WORLD")
})

test_that("Workflow cache hits emit station_completed with no deltas", {
  wf <- Workflow$new("W", use_cache = TRUE)
  wf$add_station("write", streaming_agent("writer"))
  wf$run("go", on_event = function(e) NULL)

  col <- event_collector()
  wf$run("go", on_event = col$callback)

  expect_equal(
    col$types(),
    c("workflow_started", "station_started", "station_completed", "workflow_output")
  )
  expect_true(col$events[[3]]$data$from_cache)
})

test_that("Agent-like handlers with a one-argument invoke() still work when streaming", {
  OneArgAgent <- R6::R6Class(
    classname = "Agent",
    public = list(invoke = function(input) "plain")
  )
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", OneArgAgent$new())
  col <- event_collector()

  expect_equal(wf$run("go", on_event = col$callback), "plain")
  expect_equal(
    col$types(),
    c("workflow_started", "station_started", "station_completed", "workflow_output")
  )
})

test_that("Workflow streams retries and fallback", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station(
    "flaky", function(x) stop("boom"),
    max_retries = 1L, retry_delay = 0,
    fallback = function(input, error) "recovered"
  )
  col <- event_collector()

  res <- wf$run("go", on_event = col$callback)

  expect_equal(res, "recovered")
  expect_equal(
    col$types(),
    c("workflow_started", "station_started", "station_retry",
      "station_fallback", "station_completed", "workflow_output")
  )
  expect_equal(col$events[[3]]$data$station, "flaky")
  expect_equal(col$events[[3]]$data$error, "boom")
})

test_that("a cancellation is never retried nor sent to the fallback", {
  wf <- Workflow$new("W", use_cache = FALSE)
  agent <- streaming_agent("writer")
  fallback_called <- FALSE
  wf$add_station(
    "write", agent, max_retries = 3L, retry_delay = 0,
    fallback = function(input, error) { fallback_called <<- TRUE; "fb" }
  )
  cancel <- function(e) if (e$type == "text_delta") stop("stop now")

  err <- tryCatch(wf$run("go", on_event = cancel), error = function(e) e)
  expect_s3_class(err, "mini007_stream_cancelled")
  expect_equal(agent$llm_object$stream_calls, 1L)
  expect_false(fallback_called)
})

test_that("Workflow emits workflow_failed before re-raising a station error", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("bad", function(x) stop("kaboom"))
  col <- event_collector()

  expect_error(wf$run("go", on_event = col$callback), "kaboom")
  types <- col$types()
  expect_equal(types[[length(types)]], "workflow_failed")
  expect_match(col$events[[length(types)]]$data$error, "kaboom")
})

test_that("pause-mode HITL emits hitl_request and resume() streams to its own callback", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("s1", function(x) paste0(x, "-1"))
  wf$add_station("s2", function(x) paste0(x, "-2"))
  wf$add_route("s1", "s2")
  wf$set_hitl(1L, mode = "pause")

  first <- event_collector()
  pending <- wf$run("in", on_event = first$callback)

  expect_true(is_pending(pending))
  expect_equal(first$types()[[length(first$types())]], "hitl_request")
  expect_identical(first$events[[length(first$events)]]$data$pending, pending)

  second <- event_collector()
  res <- wf$resume(pending$request_id, "edit", value = "edited",
                   on_event = second$callback)

  expect_equal(res, "edited-2")
  expect_equal(
    second$types(),
    c("station_started", "station_completed", "workflow_output")
  )
  expect_length(first$events, 4L)
})

test_that("parallel groups never ship the callback to daemons", {
  wf <- Workflow$new("W", use_cache = FALSE)
  wf$add_station("start", function(x) x)
  wf$add_station("a", function(x) paste0(x, "-a"))
  wf$add_station("b", function(x) paste0(x, "-b"))
  wf$add_parallel_group("start", c("a", "b"))
  wf$add_route("start", "a")

  mirai::daemons(1L)
  on.exit(mirai::daemons(0L), add = TRUE)

  col <- event_collector()
  res <- wf$run("x", on_event = col$callback)

  expect_equal(res, "x-a\nx-b")
  completed <- Filter(function(e) e$type == "station_completed", col$events)
  expect_setequal(vapply(completed, function(e) e$data$station, character(1)), c("a", "b"))
  expect_true(all(vapply(completed, function(e) isTRUE(e$data$parallel), logical(1))))
})

# ── WorkflowAgent + LeadAgent ─────────────────────────────────────────────────

setup_streaming_lead <- function(sub_agents) {
  lead <- LeadAgent$new(name = "Leader", llm_object = StreamingChat$new())
  lead$register_agents(sub_agents)
  lead$plan <- lapply(seq_along(sub_agents), function(i) {
    list(
      agent_id   = sub_agents[[i]]$agent_id,
      agent_name = sub_agents[[i]]$name,
      prompt     = paste("task", i)
    )
  })
  lead$prompt_for_plan <- "do it"
  lead$agents_for_plan <- vapply(sub_agents, function(a) a$name, character(1))
  lead
}

test_that("LeadAgent$invoke streams plan, tasks, nested deltas and output", {
  inner <- Workflow$new("Inner", use_cache = FALSE)
  inner$add_station("draft", streaming_agent("drafter", list("abc")))
  wf_agent <- inner$as_agent(name = "wf_agent", instruction = "wraps a workflow")

  writer <- streaming_agent("writer", list("x", "y"))
  lead <- setup_streaming_lead(list(writer, wf_agent))
  col <- event_collector()

  res <- lead$invoke("do it", on_event = col$callback)

  expect_equal(res, "abc")
  types <- col$types()
  expect_equal(types[[1]], "plan_created")
  expect_true(col$events[[1]]$data$reused)
  expect_equal(types[[length(types)]], "lead_output")
  expect_equal(col$events[[length(types)]]$text, "abc")
  expect_equal(sum(types == "task_started"), 2L)
  expect_equal(sum(types == "task_completed"), 2L)

  deltas <- Filter(function(e) e$type == "text_delta", col$events)
  expect_equal(vapply(deltas, function(e) e$source, character(1)),
               c("writer", "writer", "drafter"))
  expect_equal(deltas[[1]]$data$task, 1L)
  expect_equal(deltas[[1]]$data$agent, "writer")
  nested <- deltas[[3]]
  expect_equal(nested$data$task, 2L)
  expect_equal(nested$data$agent, "wf_agent")
  expect_equal(nested$data$station, "draft")
  expect_equal(nested$data$step, 1L)
})

test_that("LeadAgent pause-mode HITL emits hitl_request and resumes streaming", {
  a1 <- streaming_agent("a1", list("one"))
  a2 <- streaming_agent("a2", list("two"))
  lead <- setup_streaming_lead(list(a1, a2))
  lead$set_hitl(1L, mode = "pause")

  first <- event_collector()
  pending <- lead$invoke("do it", on_event = first$callback)
  expect_true(is_pending(pending))
  expect_equal(first$types()[[length(first$types())]], "hitl_request")

  second <- event_collector()
  res <- lead$resume(pending$request_id, "continue", on_event = second$callback)
  expect_equal(res, "two")
  expect_equal(second$types()[[1]], "task_started")
  expect_equal(second$types()[[length(second$types())]], "lead_output")
})
