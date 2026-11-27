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

# Chat mock for plan_and_execute(): $chat_structured() returns the queued
# plan, $chat() and $stream() answer each step with "Done: <step line>" (or a
# queued reply). Both record their turns like ellmer, and the mock records
# how many tools were registered at each call.
PlanChat <- R6::R6Class(
  "Chat",
  public = list(
    system_prompt = NULL,
    turns = list(),
    tools = list(),
    provider = provider,
    plan = list(steps = list("Find careers", "Find programs", "Find funding")),
    replies = list(),
    fail_on_call = NULL,
    plan_prompts = list(),
    prompts = list(),
    tools_at_plan = NULL,
    tools_at_chat = integer(0),

    chat_structured = function(prompt, type) {
      self$plan_prompts[[length(self$plan_prompts) + 1L]] <- prompt
      self$tools_at_plan <- length(self$tools)
      self$add_turns(prompt, "plan")
      self$plan
    },

    chat = function(prompt) {
      out <- self$reply(prompt)
      self$add_turns(prompt, out)
      out
    },

    stream = function(prompt, stream = c("text", "content")) {
      out <- self$reply(prompt)
      chat <- self
      coro::generator(function() {
        coro::yield(ellmer::ContentText(out))
        chat$add_turns(prompt, out)
      })()
    },

    reply = function(prompt) {
      self$prompts[[length(self$prompts) + 1L]] <- prompt
      self$tools_at_chat <- c(self$tools_at_chat, length(self$tools))
      if (identical(self$fail_on_call, length(self$prompts))) stop("provider down")
      if (length(self$replies) > 0L) {
        out <- self$replies[[1L]]
        self$replies <- self$replies[-1L]
        return(out)
      }
      step <- regmatches(prompt, regexpr("step [0-9]+ of [0-9]+ now: [^\n]*", prompt))
      if (length(step)) paste("Done:", sub("^step [0-9]+ of [0-9]+ now: ", "", step)) else "Final answer"
    },

    add_turns = function(prompt, out) {
      self$turns <- c(self$turns, list(
        ellmer::Turn("user", list(ellmer::ContentText(prompt))),
        ellmer::Turn("assistant", list(ellmer::ContentText(out)))
      ))
    },

    last_turn = function() self$turns[[length(self$turns)]],
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
    set_tools = function(tools) { self$tools <- tools },
    get_tools = function() self$tools,
    get_provider = function() self$provider
  )
)

search_careers <- ellmer::tool(
  function(interest) "Teacher",
  name = "search_careers",
  description = "Career Database API: find careers for one interest.",
  arguments = list(interest = ellmer::type_string("One interest."))
)

plan_agent <- function(plan = NULL, tools = list(search_careers), ...) {
  chat <- PlanChat$new()
  if (!is.null(plan)) chat$plan <- list(steps = as.list(plan))
  agent <- Agent$new("advisor", "You are a career advisor.", chat, ...)
  if (length(tools) > 0) suppressMessages(agent$register_tools(tools))
  agent
}

# ── Plan, execute, answer ─────────────────────────────────────────────────────

test_that("plan_and_execute() plans once, runs each step in order, then answers", {
  agent <- plan_agent()
  answer <- agent$plan_and_execute("I'm creative. Careers, programs and funding?")

  chat <- agent$llm_object
  expect_length(chat$plan_prompts, 1)
  expect_length(chat$prompts, 4)
  expect_equal(answer, "Final answer")

  plan <- agent$last_plan
  expect_equal(plan$prompt, "I'm creative. Careers, programs and funding?")
  expect_equal(plan$steps$step, 1:3)
  expect_equal(plan$steps$task, c("Find careers", "Find programs", "Find funding"))
  expect_equal(plan$steps$result, paste("Done:", plan$steps$task))
  expect_equal(plan$answer, "Final answer")
  expect_s3_class(plan$timestamp, "POSIXct")
})

test_that("the first step gets the task and the plan; later steps get only their own line", {
  agent <- plan_agent()
  agent$plan_and_execute("My task")
  prompts <- agent$llm_object$prompts

  expect_match(prompts[[1]], "Task:\nMy task", fixed = TRUE)
  expect_match(prompts[[1]], "Plan:\n1) Find careers\n2) Find programs\n3) Find funding", fixed = TRUE)
  expect_match(prompts[[1]], "Carry out step 1 of 3 now: Find careers", fixed = TRUE)

  expect_match(prompts[[2]], "Carry out step 2 of 3 now: Find programs", fixed = TRUE)
  expect_false(grepl("Plan:", prompts[[2]], fixed = TRUE))

  expect_match(prompts[[4]], "write the final answer to the original task:\nMy task", fixed = TRUE)
})

test_that("the planner sees the tools but cannot call them; the steps can", {
  agent <- plan_agent()
  agent$plan_and_execute("task")
  chat <- agent$llm_object

  expect_match(chat$plan_prompts[[1]], "- search_careers: Career Database API", fixed = TRUE)
  expect_equal(chat$tools_at_plan, 0L)
  expect_equal(chat$tools_at_chat, rep(1L, 4))
  expect_length(chat$get_tools(), 1)
})

test_that("an agent without tools plans without them", {
  agent <- plan_agent(tools = list())
  agent$plan_and_execute("task")
  expect_match(agent$llm_object$plan_prompts[[1]], "You have no tools", fixed = TRUE)
  expect_match(agent$llm_object$plan_prompts[[1]], "at most 6 steps", fixed = TRUE)
})

test_that("a plan longer than max_steps is cut down", {
  agent <- plan_agent(plan = c("one", "two", "three", "four"))
  expect_message(agent$plan_and_execute("task", max_steps = 2), "keeping the first 2")
  expect_equal(agent$last_plan$steps$task, c("one", "two"))
  expect_length(agent$llm_object$prompts, 3)
  expect_match(agent$llm_object$plan_prompts[[1]], "at most 2 steps", fixed = TRUE)
})

test_that("blank steps are dropped and an empty plan goes straight to the answer", {
  agent <- plan_agent(plan = c("  ", ""))
  answer <- agent$plan_and_execute("Just say hi")
  expect_equal(answer, "Final answer")
  expect_equal(nrow(agent$last_plan$steps), 0)
  expect_length(agent$llm_object$prompts, 1)
})

test_that("max_steps must be a positive whole number", {
  agent <- plan_agent()
  expect_error(agent$plan_and_execute("task", max_steps = 0))
  expect_error(agent$plan_and_execute("task", max_steps = 2.5))
  expect_error(agent$plan_and_execute(c("a", "b")))
})

# ── Bookkeeping ───────────────────────────────────────────────────────────────

test_that("messages and cost are synced as with invoke()", {
  agent <- plan_agent()
  agent$plan_and_execute("task")

  expect_equal(agent$cost, 0.5)
  # system + (plan + 3 steps + answer) x (user, assistant)
  expect_length(agent$messages, 11)
  expect_equal(agent$messages[[11]]$content, "Final answer")
})

test_that("a failing step stops the run but keeps the results so far", {
  agent <- plan_agent()
  agent$llm_object$fail_on_call <- 2L

  expect_error(agent$plan_and_execute("task"), "could not get a response")

  steps <- agent$last_plan$steps
  expect_equal(steps$result[1], "Done: Find careers")
  expect_true(all(is.na(steps$result[2:3])))
  expect_true(is.na(agent$last_plan$answer))
  expect_equal(agent$messages[[length(agent$messages)]]$content, "Done: Find careers")
})

test_that("an exceeded budget stops the run before the plan is made", {
  agent <- plan_agent(budget = 0.1)
  expect_error(agent$plan_and_execute("task"), "budget")
  expect_length(agent$llm_object$plan_prompts, 0)
})

# ── Streaming ─────────────────────────────────────────────────────────────────

test_that("streaming emits the plan, each step and the answer, in order", {
  agent <- plan_agent(plan = c("Find careers", "Find funding"))
  events <- list()

  answer <- agent$plan_and_execute("task", on_event = function(e) {
    events[[length(events) + 1L]] <<- e
  })

  types <- vapply(events, function(e) e$type, character(1))
  expect_equal(types, c(
    "plan_created",
    "step_started", "agent_started", "text_delta", "agent_completed", "step_completed",
    "step_started", "agent_started", "text_delta", "agent_completed", "step_completed",
    "answer_started", "agent_started", "text_delta", "agent_completed", "plan_completed"
  ))
  expect_equal(events[[1]]$data$steps, c("Find careers", "Find funding"))
  expect_equal(events[[2]]$data$task, "Find careers")
  expect_equal(events[[4]]$data$step, 1L)
  expect_equal(events[[9]]$data$step, 2L)
  expect_equal(events[[6]]$text, "Done: Find careers")
  expect_equal(events[[16]]$text, answer)
  expect_equal(answer, "Final answer")
})

test_that("stream = TRUE prints the plan and steps and returns the answer invisibly", {
  agent <- plan_agent(plan = c("Find careers"))
  out <- NULL
  printed <- capture.output(
    messages <- capture.output(
      out <- withVisible(agent$plan_and_execute("task", stream = TRUE)),
      type = "message"
    )
  )
  expect_false(out$visible)
  expect_equal(out$value, "Final answer")
  all_output <- paste(c(printed, messages), collapse = "\n")
  expect_match(all_output, "Find careers")
  expect_match(all_output, "Final answer")
})

test_that("ReActAgent and other Agent subclasses inherit plan_and_execute()", {
  expect_true("plan_and_execute" %in% names(ReActAgent$get_inherit()$public_methods))
  expect_true(is.function(Agent$public_methods$plan_and_execute))
})
