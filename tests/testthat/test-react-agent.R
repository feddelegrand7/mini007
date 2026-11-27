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

# Mock of an ellmer Chat that runs a scripted tool loop the way ellmer does:
# each $chat() call plays assistant turns from `script` until one has no tool
# request. The assistant turn is recorded before its tools run, every request
# goes through the on_tool_request callbacks (which may refuse it with
# ellmer::tool_reject()), the registered tools really run, and their results
# form the next user turn. Like ellmer, refused calls end in a warning.
ScriptedToolChat <- R6::R6Class(
  "Chat",
  public = list(
    system_prompt = NULL,
    turns = list(),
    tools = list(),
    callbacks = list(),
    script = NULL,
    position = 0L,
    next_callback_id = 0L,
    provider = provider,

    initialize = function(script = list()) {
      self$script <- script
    },

    chat = function(prompt) {
      user <- ellmer::Turn("user", list(ellmer::ContentText(prompt)))
      refused <- character(0)

      repeat {
        self$position <- self$position + 1L
        if (self$position > length(self$script)) stop("script exhausted")
        assistant <- ellmer::Turn("assistant", self$script[[self$position]])
        self$turns <- c(self$turns, list(user, assistant))

        requests <- Filter(
          function(ct) inherits(ct, "ellmer::ContentToolRequest"),
          assistant@contents
        )
        if (length(requests) == 0) break

        results <- lapply(requests, function(request) {
          refusal <- tryCatch(
            {
              for (callback in self$callbacks) callback(request)
              NULL
            },
            ellmer_tool_reject = function(e) conditionMessage(e)
          )
          if (!is.null(refusal)) {
            refused <<- c(refused, refusal)
            return(ellmer::ContentToolResult(error = refusal, request = request))
          }
          tryCatch(
            ellmer::ContentToolResult(
              value = do.call(self$tools[[request@name]], request@arguments),
              request = request
            ),
            error = function(e) ellmer::ContentToolResult(error = e, request = request)
          )
        })
        user <- ellmer::Turn("user", results)
      }

      if (length(refused) > 0) {
        warning(paste("Failed to evaluate", length(refused), "tool calls.", refused[[1]]))
      }
      assistant@text
    },

    on_tool_request = function(callback) {
      self$next_callback_id <- self$next_callback_id + 1L
      id <- as.character(self$next_callback_id)
      self$callbacks[[id]] <- callback
      invisible(function() {
        self$callbacks[[id]] <- NULL
        invisible()
      })
    },

    register_tools = function(tools) {
      names(tools) <- vapply(tools, function(t) t@name, character(1))
      self$tools <- tools
    },
    set_tools = function(tools) { self$tools <- tools },
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
    get_provider = function() self$provider
  )
)

text <- function(x) ellmer::ContentText(x)
call_tool <- function(id, name, ...) {
  ellmer::ContentToolRequest(id = id, name = name, arguments = list(...))
}

calls <- new.env()

search_careers <- ellmer::tool(
  function(interests) {
    calls$search <- c(calls$search, interests)
    "UX Designer, Teacher"
  },
  name = "search_careers",
  description = "Search careers by interests.",
  arguments = list(interests = ellmer::type_string("Interests."))
)

find_programs <- ellmer::tool(
  function(career) {
    calls$programs <- c(calls$programs, career)
    if (career == "Astronaut") stop("no programs for this career")
    paste(career, "bootcamp")
  },
  name = "find_programs",
  description = "Find programs for a career.",
  arguments = list(career = ellmer::type_string("Career title."))
)

react_agent <- function(script, max_steps = 10, tools = list(search_careers, find_programs)) {
  rm(list = ls(calls), envir = calls)
  suppressMessages(
    ReActAgent$new(
      name = "advisor",
      instruction = "You are a career advisor.",
      llm_object = ScriptedToolChat$new(script),
      tools = tools,
      max_steps = max_steps
    )
  )
}

# ── Construction ──────────────────────────────────────────────────────────────

test_that("ReActAgent is an Agent whose system prompt adds the ReAct guidance", {
  agent <- react_agent(list())

  expect_true(inherits(agent, "Agent"))
  expect_equal(agent$role, "You are a career advisor.")
  expect_true(startsWith(agent$instruction, "You are a career advisor."))
  expect_match(agent$instruction, "Thought, Action and Observation")
  expect_equal(agent$llm_object$get_system_prompt(), agent$instruction)
  expect_equal(agent$messages[[1]]$content, agent$instruction)
  expect_setequal(agent$list_tools(), c("search_careers", "find_programs"))
  expect_equal(agent$max_steps, 10L)
  expect_equal(nrow(agent$trace), 0)
})

test_that("max_steps must be a positive whole number", {
  expect_error(react_agent(list(), max_steps = 0))
  expect_error(react_agent(list(), max_steps = 1.5))
  expect_error(react_agent(list(), max_steps = "3"))
})

test_that("invoke() refuses to run without tools", {
  agent <- react_agent(list(text("hi")), tools = list())
  expect_error(agent$invoke("hello"), "has no tools")
})

test_that("update_instruction() changes the role and keeps the ReAct guidance", {
  agent <- react_agent(list())
  suppressMessages(agent$update_instruction("You are a tutor."))

  expect_equal(agent$role, "You are a tutor.")
  expect_true(startsWith(agent$instruction, "You are a tutor."))
  expect_match(agent$instruction, "Thought, Action and Observation")
  expect_equal(agent$llm_object$get_system_prompt(), agent$instruction)
})

# ── The ReAct loop ────────────────────────────────────────────────────────────

test_that("invoke() runs Think/Act/Observe steps and records them in $trace", {
  agent <- react_agent(list(
    list(text("I should find careers first."), call_tool("c1", "search_careers", interests = "art")),
    list(
      text("Now programs for both careers."),
      call_tool("c2", "find_programs", career = "UX Designer"),
      call_tool("c3", "find_programs", career = "Teacher")
    ),
    list(text("Try UX Designer: there is a bootcamp."))
  ))

  answer <- agent$invoke("I'm creative. What should I do?")

  expect_equal(answer, "Try UX Designer: there is a bootcamp.")
  expect_equal(calls$search, "art")
  expect_equal(calls$programs, c("UX Designer", "Teacher"))

  trace <- agent$trace
  expect_equal(
    trace$type,
    c("think", "act", "observe", "think", "act", "act", "observe", "observe", "answer")
  )
  expect_equal(trace$step, c(1L, 1L, 1L, 2L, 2L, 2L, 2L, 2L, 3L))
  expect_equal(
    trace$tool[trace$type %in% c("act", "observe")],
    c("search_careers", "search_careers", rep("find_programs", 4))
  )
  expect_equal(trace$content[2], '{"interests":"art"}')
  expect_equal(trace$content[3], "UX Designer, Teacher")
  expect_equal(trace$content[7:8], c("UX Designer bootcamp", "Teacher bootcamp"))
  expect_false(any(trace$is_error))

  # Like Agent$invoke(): history and cost are synced from the turns.
  expect_equal(agent$cost, 0.5)
  expect_equal(agent$messages[[length(agent$messages)]]$content, answer)
})

test_that("a failing tool is observed as an error and the loop continues", {
  agent <- react_agent(list(
    list(call_tool("c1", "find_programs", career = "Astronaut")),
    list(text("No programs were found for astronauts."))
  ))

  answer <- agent$invoke("How do I become an astronaut?")

  expect_equal(answer, "No programs were found for astronauts.")
  observe <- agent$trace[agent$trace$type == "observe", ]
  expect_true(observe$is_error)
  expect_match(observe$content, "no programs for this career")
})

test_that("$trace only covers the last run", {
  agent <- react_agent(list(
    list(call_tool("c1", "search_careers", interests = "art")),
    list(text("First answer.")),
    list(text("Second answer, no tools needed."))
  ))

  agent$invoke("first")
  expect_equal(nrow(agent$trace), 3)

  agent$invoke("second")
  expect_equal(agent$trace$type, "answer")
  expect_equal(agent$trace$step, 1L)
})

# ── Step limit ────────────────────────────────────────────────────────────────

test_that("tool calls past max_steps are refused and the LLM answers with what it has", {
  agent <- react_agent(
    list(
      list(call_tool("c1", "search_careers", interests = "art")),
      list(call_tool("c2", "find_programs", career = "Teacher")),
      list(text("Teacher fits; I could not look up programs."))
    ),
    max_steps = 1
  )

  expect_no_warning(
    expect_message(
      answer <- agent$invoke("help"),
      "max_steps"
    )
  )

  expect_equal(answer, "Teacher fits; I could not look up programs.")
  expect_null(calls$programs)
  refused <- agent$trace[agent$trace$type == "observe" & agent$trace$step == 2, ]
  expect_true(refused$is_error)
  expect_match(refused$content, "step limit is reached")
  # The guard is removed after the run.
  expect_length(agent$llm_object$callbacks, 0)
})

test_that("an LLM that keeps calling tools after the limit stops the run", {
  agent <- react_agent(
    list(
      list(call_tool("c1", "search_careers", interests = "art")),
      list(call_tool("c2", "search_careers", interests = "music")),
      list(call_tool("c3", "search_careers", interests = "sport")),
      list(text("never reached"))
    ),
    max_steps = 1
  )

  err <- expect_error(agent$invoke("help"), class = "mini007_react_step_limit")
  expect_s3_class(err, "mini007_react_step_limit")
  expect_equal(calls$search, "art")

  # The trace and the message history still reflect the steps taken.
  expect_equal(max(agent$trace$step), 3L)
  expect_match(agent$messages[[length(agent$messages)]]$content, "search_careers")
  expect_length(agent$llm_object$callbacks, 0)
})

test_that("several tool calls in one turn count as a single step", {
  agent <- react_agent(
    list(
      list(
        call_tool("c1", "find_programs", career = "UX Designer"),
        call_tool("c2", "find_programs", career = "Teacher"),
        call_tool("c3", "find_programs", career = "Nurse")
      ),
      list(text("Here are the programs."))
    ),
    max_steps = 1
  )

  expect_no_message(answer <- agent$invoke("programs please"))
  expect_equal(answer, "Here are the programs.")
  expect_equal(calls$programs, c("UX Designer", "Teacher", "Nurse"))
  expect_false(any(agent$trace$is_error))
})

# ── Printing ──────────────────────────────────────────────────────────────────

test_that("print_trace() shows each step", {
  agent <- react_agent(list(
    list(text("Find careers."), call_tool("c1", "search_careers", interests = "art")),
    list(text("Go for UX Designer."))
  ))

  expect_message(agent$print_trace(), "No run recorded yet")

  agent$invoke("help")
  output <- paste(utils::capture.output(agent$print_trace()), collapse = "\n")
  expect_match(output, "Step 1")
  expect_match(output, "Think: Find careers.", fixed = TRUE)
  expect_match(output, 'Act: search_careers({"interests":"art"})', fixed = TRUE)
  expect_match(output, "Observe search_careers: UX Designer, Teacher", fixed = TRUE)
  expect_match(output, "Answer: Go for UX Designer.", fixed = TRUE)
})
