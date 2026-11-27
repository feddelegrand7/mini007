# Prompts and helpers for Agent$plan_and_execute(). The method itself lives in
# the Agent class (R/Agent.R).

# The planning request: the task, the tools the agent can use, and the rules
# for a good plan. The final "combine the results" step is not part of the
# plan: plan_and_execute() always ends with it.
plan_prompt <- function(task, tools, max_steps) {
  tool_lines <- if (length(tools) > 0) {
    paste0(
      "Tools you will be able to use while carrying out the steps:\n",
      paste0("- ", names(tools), ": ", vapply(tools, tool_description, character(1)),
             collapse = "\n"),
      "\n\n"
    )
  } else {
    "You have no tools for this task.\n\n"
  }

  paste0(
    "Make a plan for the task below. Do not carry it out yet.\n\n",
    "Task:\n", task, "\n\n",
    tool_lines,
    "Rules for the plan:\n",
    "- List the steps in the order they must be done, at most ", max_steps, " steps.\n",
    "- Use as few steps as the task needs. Every step must find or produce ",
    "something the final answer uses; do not add steps for reviewing, choosing, ",
    "evaluating or planning unless the task asks for them.\n",
    "- Each step is one short sentence describing one action. When a step needs ",
    "a tool, name the tool.\n",
    "- A later step can use the results of earlier steps.\n",
    "- Do not add a final step that combines the results or writes the answer: ",
    "that is done separately after the last step."
  )
}

# The request for one step. The first step restates the task and the full
# plan; later steps can rely on the conversation so far.
step_prompt <- function(i, steps, task) {
  n <- length(steps)
  header <- if (i == 1L) {
    paste0(
      "Task:\n", task, "\n\n",
      "Plan:\n", paste0(seq_len(n), ") ", steps, collapse = "\n"), "\n\n"
    )
  } else {
    ""
  }

  paste0(
    header,
    "Carry out step ", i, " of ", n, " now: ", steps[[i]], "\n",
    "Do only this step, using your tools if they help, and report its result. ",
    "Do not move on to the next steps or write the final answer yet."
  )
}

final_answer_prompt <- function(task) {
  paste0(
    "All the steps of the plan are done. Using their results, write the final ",
    "answer to the original task:\n", task, "\n",
    "Rely on what the steps found; if something could not be found, say so."
  )
}

tool_description <- function(tool) {
  description <- tryCatch(tool@description, error = function(e) "")
  if (!is.character(description) || length(description) != 1L || is.na(description)) {
    return("")
  }
  trimws(gsub("\\s+", " ", description))
}

plan_steps_type <- function() {
  ellmer::type_object(
    steps = ellmer::type_array(
      items = ellmer::type_string(description = "One step: a short sentence describing one action."),
      description = "The steps of the plan, in the order they must be carried out."
    )
  )
}
