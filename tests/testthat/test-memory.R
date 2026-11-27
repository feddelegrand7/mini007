library(testthat)
library(mini007)

providerclass <- setClass(
  "Provider",
  slots = c(
    name = "character",
    model = "character"
  ))

provider <- new("Provider", name = "dummy", model = "v0")

# Chat mock with queues for $chat() and $chat_structured(), recording every
# prompt it receives and the system prompt in place at the time.
LearningChat <- R6::R6Class(
  "Chat",
  public = list(
    system_prompt = NULL,
    turns = list(),
    tools = list(),
    provider = provider,
    chat_queue = list(),
    structured_queue = list(),
    prompts = list(),
    system_prompts_seen = list(),

    chat = function(prompt) {
      self$prompts[[length(self$prompts) + 1L]] <- prompt
      self$system_prompts_seen[[length(self$system_prompts_seen) + 1L]] <- self$system_prompt
      if (length(self$chat_queue) > 0L) {
        out <- self$chat_queue[[1L]]
        self$chat_queue <- self$chat_queue[-1L]
      } else {
        out <- paste("Echo:", prompt)
      }
      # Agent$invoke() rebuilds its messages from the turns.
      self$turns <- c(self$turns, list(
        ellmer::Turn(role = "user", contents = list(ellmer::ContentText(prompt))),
        ellmer::Turn(role = "assistant", contents = list(ellmer::ContentText(out)))
      ))
      out
    },
    chat_structured = function(prompt, type) {
      self$prompts[[length(self$prompts) + 1L]] <- prompt
      out <- self$structured_queue[[1L]]
      self$structured_queue <- self$structured_queue[-1L]
      out
    },
    get_cost = function() 0,
    set_system_prompt = function(value) { self$system_prompt <- value },
    get_system_prompt = function() if (!is.null(self$system_prompt)) self$system_prompt else "default",
    set_turns = function(turns) { self$turns <- turns },
    get_turns = function(include_system_prompt = FALSE) self$turns,
    register_tools = function(tools) { self$tools <- tools },
    get_provider = function() self$provider
  )
)

MockSubAgent <- R6::R6Class(
  "MockSubAgent",
  public = list(
    name = NULL,
    agent_id = NULL,
    instruction = "mock",
    response = NULL,
    prompts_received = NULL,
    initialize = function(name, agent_id, response) {
      self$name <- name
      self$agent_id <- agent_id
      self$response <- response
      self$prompts_received <- list()
    },
    invoke = function(prompt) {
      self$prompts_received[[length(self$prompts_received) + 1L]] <- prompt
      self$response
    }
  )
)

setup_lead <- function() {
  chat <- LearningChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = chat)
  # The Agent constructor deep-clones the chat: script the lead's own copy.
  chat <- lead$llm_object

  a1 <- MockSubAgent$new("agent1", "id1", "response1")
  a2 <- MockSubAgent$new("agent2", "id2", "response2")
  suppressMessages(lead$register_agents(list(a1, a2)))

  lead$prompt_for_plan <- "do the thing"
  lead$agents_for_plan <- c("agent1", "agent2")
  lead$plan <- list(
    list(agent_id = "id1", agent_name = "agent1", prompt = "task1",
         model_provider = "dummy", model_name = "v0"),
    list(agent_id = "id2", agent_name = "agent2", prompt = "task2",
         model_provider = "dummy", model_name = "v0")
  )

  list(lead = lead, chat = chat, a1 = a1, a2 = a2)
}

verdict <- function(score, lesson = NULL) {
  out <- list(score = score, feedback = paste("feedback", score))
  if (!is.null(lesson)) out$lesson <- lesson
  out
}

# ── Memory ───────────────────────────────────────────────────────────────────

test_that("add_lesson and add_outcome store complete records", {
  memory <- Memory$new()
  memory$add_lesson("Use metric units.", task = "Convert", agent_name = "a", score = 0.9, success = TRUE)
  memory$add_outcome("a", "Convert", success = TRUE, score = 0.9)

  expect_length(memory$lessons, 1L)
  expect_equal(memory$lessons[[1L]]$lesson, "Use metric units.")
  expect_true(nzchar(memory$lessons[[1L]]$id))
  expect_length(memory$outcomes, 1L)
  expect_equal(memory$outcomes[[1L]]$source, "validation")
})

test_that("add_lesson validates its inputs", {
  memory <- Memory$new()
  expect_error(memory$add_lesson(""))
  expect_error(memory$add_lesson("ok", score = "high"))
  expect_error(memory$add_outcome("a", "t", success = "yes"))
})

test_that("search ranks lessons by relevance and drops unrelated ones", {
  memory <- Memory$new()
  memory$add_lesson("Keep product names in English when translating to German.",
                    task = "Translate a product description to German")
  memory$add_lesson("Report GDP figures with the year they refer to.",
                    task = "Describe the economy of Algeria")
  memory$add_lesson("Prefer bullet points for summaries.", task = "Summarise a report")

  found <- memory$search("Translate this text into German", k = 3)
  expect_length(found, 1L)
  expect_match(found[[1L]]$lesson, "German")

  found <- memory$search("GDP growth of the Algerian economy", k = 1)
  expect_match(found[[1L]]$lesson, "GDP")

  expect_length(memory$search("quantum chromodynamics"), 0L)
  expect_length(memory$search("German", k = 0), 0L)
})

test_that("search can be restricted to one agent", {
  memory <- Memory$new()
  memory$add_lesson("German lesson one.", agent_name = "translator")
  memory$add_lesson("German lesson two.", agent_name = "writer")

  found <- memory$search("German", agent_name = "writer")
  expect_length(found, 1L)
  expect_equal(found[[1L]]$agent_name, "writer")
})

test_that("a custom search_fn replaces the built-in retrieval", {
  memory <- Memory$new(search_fn = function(query, lessons, k) rev(lessons))
  memory$add_lesson("first")
  memory$add_lesson("second")

  found <- memory$search("anything", k = 1)
  expect_equal(found[[1L]]$lesson, "second")
})

test_that("max_lessons and max_outcomes drop the oldest records", {
  memory <- Memory$new(max_lessons = 2, max_outcomes = 2)
  for (i in 1:3) {
    memory$add_lesson(paste("lesson", i))
    memory$add_outcome("a", paste("task", i), success = TRUE)
  }
  expect_equal(vapply(memory$lessons, `[[`, "", "lesson"), c("lesson 2", "lesson 3"))
  expect_equal(vapply(memory$outcomes, `[[`, "", "task"), c("task 2", "task 3"))
})

test_that("track_record summarises outcomes per agent, including agents without any", {
  memory <- Memory$new()
  memory$add_outcome("a", "t1", success = TRUE, score = 0.9)
  memory$add_outcome("a", "t2", success = FALSE, score = 0.3)
  memory$add_outcome("b", "t3", success = TRUE, source = "hitl")

  record <- memory$track_record(c("a", "b", "c"))
  expect_equal(record$agent_name, c("a", "b", "c"))
  expect_equal(record$n_tasks, c(2L, 1L, 0L))
  expect_equal(record$n_success, c(1L, 1L, 0L))
  expect_equal(record$success_rate, c(0.5, 1, NA))
  expect_equal(record$mean_score, c(0.6, NA, NA))

  expect_equal(nrow(Memory$new()$track_record()), 0L)
})

test_that("a memory with a path is saved on every change and reloaded on creation", {
  path <- tempfile(fileext = ".json")
  on.exit(unlink(path))

  memory <- Memory$new(path = path)
  memory$add_lesson("Persist me.", task = "t", agent_name = "a", score = 0.8, success = TRUE)
  memory$add_lesson("No score.")
  memory$add_lesson("Whole-number score.", score = 1)
  memory$add_outcome("a", "t", success = FALSE)
  expect_true(file.exists(path))

  reloaded <- Memory$new(path = path)
  expect_identical(reloaded$lessons, memory$lessons)
  expect_identical(reloaded$outcomes, memory$outcomes)

  reloaded$clear()
  expect_length(Memory$new(path = path)$lessons, 0L)
})

test_that("load errors on a missing file", {
  expect_error(Memory$new()$load(tempfile()), "does not exist")
})

# ── Agent ────────────────────────────────────────────────────────────────────

test_that("set_memory validates and attaches the memory", {
  agent <- Agent$new("a", "instr", LearningChat$new())
  expect_error(agent$set_memory(list()), "Memory")

  memory <- Memory$new()
  agent$set_memory(memory, k = 2)
  expect_identical(agent$memory, memory)

  agent$set_memory(NULL)
  expect_null(agent$memory)
})

test_that("invoke adds relevant lessons in front of the prompt", {
  agent <- Agent$new("translator", "instr", LearningChat$new())
  memory <- Memory$new()
  memory$add_lesson("Keep product names in English.", task = "Translate to German")
  agent$set_memory(memory)

  agent$invoke("Translate this sentence to German")
  sent <- agent$llm_object$prompts[[1L]]
  expect_match(sent, "Lessons learned from previous similar tasks", fixed = TRUE)
  expect_match(sent, "Keep product names in English.", fixed = TRUE)
  expect_match(sent, "--- Task ---\nTranslate this sentence to German", fixed = TRUE)

  agent$invoke("Unrelated question about astronomy")
  expect_identical(agent$llm_object$prompts[[2L]], "Unrelated question about astronomy")
})

test_that("learn records the outcome and a distilled lesson, restoring the system prompt", {
  agent <- Agent$new("checker", "You check facts.", LearningChat$new())
  agent$llm_object$chat_queue <- list("Always name the capital explicitly.")

  expect_error(agent$learn(list()), "set_memory")

  agent$set_memory(Memory$new())
  validation <- list(
    prompt = "Capital of Algeria?", response = "It is a city.",
    score = 0.2, feedback = "Does not mention Algiers.", valid = FALSE
  )
  suppressMessages(agent$learn(validation))

  expect_equal(agent$memory$lessons[[1L]]$lesson, "Always name the capital explicitly.")
  expect_false(agent$memory$lessons[[1L]]$success)
  expect_equal(agent$memory$outcomes[[1L]]$agent_name, "checker")
  expect_equal(agent$memory$outcomes[[1L]]$score, 0.2)

  expect_match(agent$llm_object$prompts[[1L]], "Does not mention Algiers.", fixed = TRUE)
  expect_equal(agent$llm_object$system_prompts_seen[[1L]], mini007:::lesson_system_prompt)
  expect_equal(agent$llm_object$get_system_prompt(), "You check facts.")
})

test_that("learn requires a validate_response() result", {
  agent <- Agent$new("checker", "instr", LearningChat$new())
  agent$set_memory(Memory$new())
  expect_error(agent$learn(list(prompt = "p")))
})

test_that("clone_agent shares the memory but not the chat", {
  agent <- Agent$new("a", "instr", LearningChat$new())
  memory <- Memory$new()
  agent$set_memory(memory)

  copy <- suppressMessages(agent$clone_agent("b"))
  expect_identical(copy$memory, memory)
  expect_false(identical(copy$llm_object, agent$llm_object))
})

# ── LeadAgent ────────────────────────────────────────────────────────────────

test_that("set_validation stores settings, validates inputs and can be turned off", {
  setup <- setup_lead()
  lead <- setup$lead

  suppressMessages(lead$set_validation("Be accurate.", threshold = 0.6, max_reassign = 2))
  expect_equal(lead$validation, list(criteria = "Be accurate.", threshold = 0.6, max_reassign = 2L))

  expect_error(lead$set_validation("x", threshold = 2))
  expect_error(lead$set_validation("x", max_reassign = -1))
  expect_error(lead$set_validation(""))

  suppressMessages(lead$set_validation(NULL))
  expect_null(lead$validation)
})

test_that("without validation, invoke makes no judging call", {
  setup <- setup_lead()
  result <- suppressMessages(setup$lead$invoke("do the thing"))
  expect_equal(result, "response2")
  expect_length(setup$chat$prompts, 0L)
  expect_null(setup$lead$agents_interaction[[1L]]$score)
})

test_that("validated steps that pass are scored and kept", {
  setup <- setup_lead()
  suppressMessages(setup$lead$set_validation("Be accurate.", threshold = 0.7))
  setup$chat$structured_queue <- list(verdict(0.9), verdict(0.8))

  result <- suppressMessages(setup$lead$invoke("do the thing"))

  expect_equal(result, "response2")
  step1 <- setup$lead$agents_interaction[[1L]]
  expect_equal(step1$score, 0.9)
  expect_true(step1$valid)
  expect_length(step1$attempts, 1L)
  expect_match(setup$chat$prompts[[1L]], "Validation criteria: Be accurate.", fixed = TRUE)
  expect_length(setup$a1$prompts_received, 1L)
})

test_that("a rejected step is reassigned to another agent and the best attempt is kept", {
  setup <- setup_lead()
  suppressMessages(setup$lead$set_validation("Be accurate.", threshold = 0.7, max_reassign = 1))
  setup$chat$structured_queue <- list(verdict(0.2), verdict(0.9), verdict(0.95))
  setup$chat$chat_queue <- list("id2")

  events <- list()
  suppressMessages(setup$lead$invoke(
    "do the thing",
    on_event = function(e) events[[length(events) + 1L]] <<- e
  ))

  step1 <- setup$lead$agents_interaction[[1L]]
  expect_equal(step1$agent_name, "agent2")
  expect_equal(step1$agent_id, "id2")
  expect_equal(step1$response, "response2")
  expect_equal(step1$score, 0.9)
  expect_length(step1$attempts, 2L)
  expect_equal(step1$attempts[[1L]]$agent_name, "agent1")

  # The matching prompt only offered the agents not tried yet.
  matching_prompt <- setup$chat$prompts[[2L]]
  expect_false(grepl("ID: id1", matching_prompt, fixed = TRUE))
  expect_true(grepl("ID: id2", matching_prompt, fixed = TRUE))
  expect_equal(setup$chat$get_system_prompt(), setup$lead$instruction)

  types <- vapply(events, `[[`, "", "type")
  expect_equal(sum(types == "task_validated"), 3L)
  reassigned <- events[types == "task_reassigned"][[1L]]
  expect_equal(reassigned$data$from, "agent1")
  expect_equal(reassigned$data$to, "agent2")
})

test_that("reassignment works with the classed strings ellmer returns", {
  setup <- setup_lead()
  suppressMessages(setup$lead$set_validation("Be accurate.", max_reassign = 1))
  setup$chat$structured_queue <- list(verdict(0.2), verdict(0.9), verdict(0.9))
  setup$chat$chat_queue <- list(structure("id2\n", class = c("ellmer_output", "character")))

  suppressMessages(setup$lead$invoke("do the thing"))

  expect_identical(setup$lead$agents_interaction[[1L]]$agent_id, "id2")
})

test_that("after a reassignment, re-running the same prompt starts with the agent that did best", {
  setup <- setup_lead()
  suppressMessages(setup$lead$set_validation("Be accurate.", max_reassign = 1))
  setup$chat$structured_queue <- list(verdict(0.2), verdict(0.9), verdict(0.9))
  setup$chat$chat_queue <- list("id2")
  suppressMessages(setup$lead$invoke("do the thing"))

  expect_equal(setup$lead$plan[[1L]]$agent_id, "id2")
  expect_equal(setup$lead$plan[[1L]]$agent_name, "agent2")

  setup$chat$structured_queue <- list(verdict(0.9), verdict(0.9))
  suppressMessages(setup$lead$invoke("do the thing"))
  expect_length(setup$a1$prompts_received, 1L)
})

test_that("when every attempt fails, the best-scoring one is kept", {
  setup <- setup_lead()
  suppressMessages(setup$lead$set_validation("Be accurate.", threshold = 0.7, max_reassign = 1))
  setup$chat$structured_queue <- list(verdict(0.5), verdict(0.3), verdict(0.9))
  setup$chat$chat_queue <- list("id2")

  suppressMessages(setup$lead$invoke("do the thing"))

  step1 <- setup$lead$agents_interaction[[1L]]
  expect_equal(step1$agent_name, "agent1")
  expect_equal(step1$response, "response1")
  expect_equal(step1$score, 0.5)
  expect_false(step1$valid)
  expect_length(step1$attempts, 2L)
})

test_that("max_reassign = 0 only scores responses", {
  setup <- setup_lead()
  suppressMessages(setup$lead$set_validation("Be accurate.", max_reassign = 0))
  setup$chat$structured_queue <- list(verdict(0.1), verdict(0.1))

  suppressMessages(setup$lead$invoke("do the thing"))

  expect_equal(setup$lead$agents_interaction[[1L]]$agent_name, "agent1")
  expect_length(setup$a2$prompts_received, 1L)
  expect_length(setup$chat$prompts, 2L)
})

test_that("with a memory, judged steps become outcomes and lessons used by later tasks", {
  setup <- setup_lead()
  memory <- Memory$new()
  setup$lead$set_memory(memory)
  suppressMessages(setup$lead$set_validation("Be accurate.", max_reassign = 0))
  setup$chat$structured_queue <- list(
    verdict(0.9, lesson = "For task1 style work, start with the key figure."),
    verdict(0.4, lesson = "")
  )

  suppressMessages(setup$lead$invoke("do the thing"))

  expect_length(memory$outcomes, 2L)
  expect_equal(memory$outcomes[[2L]]$agent_name, "agent2")
  expect_false(memory$outcomes[[2L]]$success)
  # Empty lessons are not stored.
  expect_length(memory$lessons, 1L)
  expect_equal(memory$lessons[[1L]]$agent_name, "agent1")

  record <- setup$lead$agent_track_record()
  expect_equal(record$agent_name, c("agent1", "agent2"))
  expect_equal(record$n_success, c(1L, 0L))

  # Second run: the lesson is retrieved for task1 and passed to the agent.
  setup$chat$structured_queue <- list(verdict(0.9, lesson = ""), verdict(0.9, lesson = ""))
  suppressMessages(setup$lead$invoke("do the thing"))
  expect_match(setup$a1$prompts_received[[2L]], "start with the key figure", fixed = TRUE)
})

test_that("the matching prompt shows each agent's track record", {
  setup <- setup_lead()
  memory <- Memory$new()
  memory$add_outcome("agent1", "Translate a menu", success = FALSE, score = 0.2)
  memory$add_outcome("agent2", "Translate a letter", success = TRUE, score = 0.9)
  setup$lead$set_memory(memory)
  setup$chat$chat_queue <- list("id2")

  agent_id <- setup$lead$.__enclos_env__$private$.match_agent_to_task("Translate a poem")

  expect_equal(agent_id, "id2")
  prompt <- setup$chat$prompts[[1L]]
  expect_match(prompt, "Track record: 1 past task(s), 0 passed, mean score 0.2", fixed = TRUE)
  expect_match(prompt, "[passed] Translate a letter", fixed = TRUE)
  expect_match(setup$chat$system_prompts_seen[[1L]], "track record", fixed = TRUE)
})

test_that("an invalid agent ID from the matcher errors and still restores the system prompt", {
  setup <- setup_lead()
  setup$chat$chat_queue <- list("not-an-id")

  expect_error(
    setup$lead$.__enclos_env__$private$.match_agent_to_task("task"),
    "invalid agent_id: not-an-id"
  )
  expect_equal(setup$chat$get_system_prompt(), setup$lead$instruction)
})

test_that("agent_track_record requires a memory", {
  setup <- setup_lead()
  expect_error(setup$lead$agent_track_record(), "set_memory")
})

test_that("HITL decisions are recorded, and an edit is distilled into a lesson", {
  setup <- setup_lead()
  memory <- Memory$new()
  setup$lead$set_memory(memory)
  setup$lead$set_hitl(c(1, 2), mode = "pause")
  setup$chat$chat_queue <- list("Answer in one sentence.")

  pending <- suppressMessages(setup$lead$invoke("do the thing"))
  pending <- suppressMessages(setup$lead$resume(pending$request_id, action = "continue"))
  suppressMessages(setup$lead$resume(pending$request_id, action = "edit", value = "Short answer."))

  expect_equal(vapply(memory$outcomes, `[[`, logical(1), "success"), c(TRUE, FALSE))
  expect_equal(vapply(memory$outcomes, `[[`, "", "source"), c("hitl", "hitl"))
  expect_length(memory$lessons, 1L)
  expect_equal(memory$lessons[[1L]]$lesson, "Answer in one sentence.")
  expect_match(setup$chat$prompts[[1L]], "Short answer.", fixed = TRUE)
})

test_that("HITL decisions without a memory record nothing and make no LLM call", {
  setup <- setup_lead()
  setup$lead$set_hitl(1, mode = "pause")

  pending <- suppressMessages(setup$lead$invoke("do the thing"))
  suppressMessages(setup$lead$resume(pending$request_id, action = "edit", value = "x"))
  expect_length(setup$chat$prompts, 0L)
})

test_that("a sub-agent with its own memory is not given the lead's lessons twice", {
  setup <- setup_lead()
  memory <- Memory$new()
  memory$add_lesson("Lesson about task1.", task = "task1")
  setup$lead$set_memory(memory)

  inner <- Agent$new("agent1", "instr", LearningChat$new())
  inner$agent_id <- "id1"
  inner$set_memory(memory)
  setup$lead$agents[[1L]] <- inner

  suppressMessages(setup$lead$invoke("do the thing"))

  sent <- inner$llm_object$prompts[[1L]]
  expect_equal(lengths(regmatches(sent, gregexpr("Lesson about task1.", sent, fixed = TRUE))), 1L)
})
