
#' Agent: A General-Purpose LLM Agent
#'
#' @description
#' The `Agent` class defines a modular LLM-based agent capable of responding to prompts using a defined role/instruction.
#' It wraps an OpenAI-compatible chat model via the [`ellmer`](https://github.com/llrs/ellmer) package.
#'
#' Each agent maintains its own message history and unique identity.
#'
#' @importFrom R6 R6Class
#' @importFrom uuid UUIDgenerate
#' @importFrom checkmate assert_string assert_flag
#' @importFrom ellmer chat_openai
#' @export
Agent <- R6::R6Class(
  classname = "Agent",

  public = list(
    #' @description
    #' Initializes a new Agent with a specific role/instruction.
    #'
    #' @param name A short identifier for the agent (e.g. `"translator"`).
    #' @param instruction The system prompt that defines the agent's role.
    #' @param llm_object The LLM object generate by ellmer (eg. output of ellmer::chat_openai)


    initialize = function(name, instruction, llm_object) {

      checkmate::assert_string(name)
      checkmate::assert_string(instruction)

      self$name <- name
      self$instruction <- instruction

      self$llm_object <- llm_object$clone(deep = TRUE)

      meta_data <-  self$llm_object$get_provider()

      self$model_provider <- meta_data@name

      self$model_name <- meta_data@model

      self$llm_object$set_system_prompt(value = instruction)

      self$messages <- list(
        list(role = "system", content = instruction)
      )

      self$agent_id <- uuid::UUIDgenerate()
    },

    #' @description
    #' Sends a user prompt to the agent and returns the assistant's response.
    #'
    #' @param prompt A character string prompt for the agent to respond to.
    #' @return The LLM-generated response as a character string.
    #' @examples \dontrun{
    #' agent <- Agent$new("translator", "Translate to French.", "gpt-4.1-mini")
    #' agent$invoke("Hello world")
    #' }
    invoke = function(prompt) {

      checkmate::assert_string(prompt)

      private$.add_user_message(prompt)
      response <- self$llm_object$chat(prompt)
      private$.add_assistant_message(response)
      return(response)
    },

    #' @field name The agent's name.
    name = NULL,
    #' @field instruction The agent's role/system prompt.
    instruction = NULL,
    #' @field llm_object The underlying `ellmer::chat_openai` object.
    llm_object = NULL,
    #' @field messages A list of past messages (system, user, assistant).
    messages = NULL,
    #' @field agent_id A UUID uniquely identifying the agent.
    agent_id = NULL,
    #'@field model_provider The name of the entity providing the model (eg. OpenAI)
    model_provider = NULL,
    #'@field model_name The name of the model to be used (eg. gpt-4.1-mini)
    model_name = NULL

  ),

  private = list(
    .add_message = function(message, type) {

      self$messages[[length(self$messages) + 1]] <- list(
        role = type,
        content = message
      )
    },

    .add_assistant_message = function(message, type = "assistant") {
      private$.add_message(message, type)
    },

    .add_user_message = function(message, type = "user") {
      private$.add_message(message, type)
    }
  )
)


#' LeadAgent: A Multi-Agent Orchestration Coordinator
#'
#' @description
#' `LeadAgent` extends `Agent` to coordinate a group of specialized agents.
#' It decomposes complex prompts into subtasks using LLMs and assigns each subtask to the most suitable registered agent.
#' The lead agent handles response chaining, where each agent can consider prior results.
#'
#' @details
#' This class builds intelligent multi-agent workflows by delegating sub-tasks using `delegate_prompt()`,
#' executing them with `invoke()`, and storing the results in the `agents_interaction` list.
#'
#' @export
LeadAgent <- R6::R6Class(
  classname = "LeadAgent",
  inherit = Agent,

  public = list(

    #' @field agents A named list of registered sub-agents (by UUID).
    agents = list(),
    #' @field agents_interaction A list of delegated task history with agent IDs, prompts, and responses.
    agents_interaction = list(),
    #' @description
    #' Initializes the LeadAgent with a built-in task-decomposition prompt.
    #' @param name A short name for the coordinator (e.g. `"lead"`).
    #' @param model The LLM model to use for decomposition and matching.
    #' @param api_key Optional. OpenAI API key; defaults to environment variable.
    initialize = function(name, llm_object) {

      system_prompt <- paste0(
        "You are a task decomposition assistant. ",
        "You receive a complex user instruction and return a list of smaller subtasks to be performed in logical order. ",
        "Return the subtasks as plain text, one per line.",
        "Within the subtasks, mentions the necessary information that should be known before executing them. ",
        "Write the subtask as it is. Do not include numerotation (like 1., 2. and so on), write the subtask plain and simple"
      )

      super$initialize(name = name, instruction = system_prompt, llm_object = llm_object)
    },

    #' @description
    #' Register one or more agents for delegation.
    #' @param agents A vector of `Agent` objects to register.
    register_agents = function(agents) {

      if (length(agents$agent_id) == 1) {
        self$agents[[agent$agent_id]] <- agent
        return(invisible(NULL))
      }

      for (i in seq_along(agents)) {
        agent <- agents[[i]]
        self$agents[[agent$agent_id]] <- agent
      }

    },

    #' @description
    #' Returns a list of subtasks with assigned agent IDs and names.
    #' @param prompt A complex instruction to be broken into subtasks.
    #' @return A list of lists, each with `agent_id`, `agent_name`, and `prompt` fields.
    #'
    delegate_prompt = function(prompt) {

      task_analysis <- private$.analyze_prompt(prompt)

      delegated <- lapply(task_analysis, function(task) {

        agent_id <- private$.match_agent_to_task(task)

        agent_name <- self$agents[[agent_id]]$name

        model_provider <- self$agents[[agent_id]]$model_provider

        model_name <- self$agents[[agent_id]]$model_name

        list(
          agent_id = agent_id,
          agent_name = agent_name,
          model_name = model_name,
          model_provider = model_provider,
          prompt = task
        )

      })

      return(delegated)

    },

    #' @description
    #' Executes the full prompt pipeline: decomposition → delegation → invocation.
    #' @param prompt The complex user instruction to process.
    #' @return The final response (from the last agent in the sequence).
    #' @examples \dontrun{
    #' lead <- LeadAgent$new("lead", "gpt-4.1-mini")
    #' lead$register_agents(list(agent1, agent2))
    #' result <- lead$invoke("Summarize a topic and translate to German.")
    #' }

    invoke = function(prompt) {

      if (length(self$agents) == 0) {

        err_msg <- paste0(
          "No Agent has been assigned yet to the LeadAgent. ",
          "Use the `registre_agents` methods to assign Agents"
        )

        stop(err_msg)
      }

      prompts_res <- self$delegate_prompt(prompt)

      for (i in seq_along(prompts_res)) {
        prompts_res[[i]]$response <- NA
      }

      for (i in seq_along(prompts_res)) {

        agent_id <- prompts_res[[i]]$agent_id
        agent <- self$agents[[agent_id]]
        prompt_to_consider <- prompts_res[[i]]$prompt

        if (i > 1) {
          previous_response <- prompts_res[[i - 1]]$response
          prompt_to_consider <- paste(
            "\n\nBefore answering consider the Previous answer:\n",
            previous_response,
            "\n\n--- This is what you should do with the previous answer ---\n",
            prompt_to_consider
          )
        }

        response <- agent$invoke(prompt_to_consider)
        prompts_res[[i]]$response <- response
      }

      self$agents_interaction <- prompts_res

      prompts_res[[length(prompts_res)]]$response

    }
  ),

  private = list(

    .analyze_prompt = function(prompt) {

      result <- self$llm_object$chat(prompt)

      tasks <- unlist(strsplit(result, "\n"))
      tasks <- trimws(tasks)
      tasks <- tasks[tasks != ""]

      return(tasks)
    },

    .match_agent_to_task = function(task) {

      agent_descriptions <- vapply(self$agents, function(agent) {
        paste0(
          "----------------",
          "\nID: ", agent$agent_id,
          "\nName: ", agent$name,
          "\nInstruction: ", agent$instruction,
          "\n---------------"
        )
      }, character(1))

      system_prompt <- paste0(
        "You are an agent-matching assistant. ",
        "Given a task and a list of available agents with their instructions, names and IDs, ",
        "pick the best-suited agent (only one) and return ONLY its ID (no explanation). The ID has a UUID structure",
        " The structure of the Agent starts with the ID and finishes with the Instruction."
      )

      base_system_prompt <- self$llm_object$get_system_prompt()

      self$llm_object$set_system_prompt(value = system_prompt)

      user_message <- paste(
        "Task:", task, "\n\n",
        "Available agents:\n",
        paste(agent_descriptions, collapse = "\n\n")
      )

      agent_id <- self$llm_object$chat(
        user_message
      )

      checkmate::assert_string(agent_id)

      agent_id <- trimws(agent_id)

      if (!agent_id %in% names(self$agents)) {
        stop("LLM returned invalid agent_id: ", agent_id)
      }

      self$llm_object$set_system_prompt(value = base_system_prompt)

      return(agent_id)

    }
  )
)

