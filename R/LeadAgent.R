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
#' @importFrom DiagrammeR grViz
#' @export
LeadAgent <- R6::R6Class(
  classname = "LeadAgent",
  inherit = Agent,

  public = list(

    #' @field agents A named list of registered sub-agents (by UUID).
    agents = list(),
    #' @field agents_interaction A list of delegated task history with agent IDs, prompts, and responses.
    agents_interaction = list(),
    #' @field plan A list containing the most recently generated task plan.
    plan = list(),
    #' @field hitl_steps The steps where the workflow should be stopped in order to allow for a human interaction
    hitl_steps = NULL,
    #'@field prompt_for_plan The prompt used to generate the plan.
    prompt_for_plan = NULL,
    #'@field agents_for_plan The agents used for the plan
    agents_for_plan = NULL,
    #' @field dialog_history A list storing the history of agent dialogs
    dialog_history = list(),
    #' @field broadcast_history A list storing the history of broadcast interactions
    broadcast_history = list(),

    #' @description
    #' Initializes the LeadAgent with a built-in task-decomposition prompt.
    #' @param name A short name for the coordinator (e.g. `"lead"`).
    #' @param llm_object The LLM object generate by ellmer (eg. output of ellmer::chat_openai)
    #' @examples
    #'
    #'   # An API KEY is required in order to invoke the agents
    #'   openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #'
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #'
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
    #' Clear out the registered Agents
    #' @examples
    #'   # An API KEY is required in order to invoke the agents
    #'   openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #'  researcher <- Agent$new(
    #'    name = "researcher",
    #'    instruction = paste0(
    #'    "You are a research assistant. ",
    #'    "Your job is to answer factual questions with detailed and accurate information. ",
    #'    "Do not answer with more than 2 lines"
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  summarizer <- Agent$new(
    #'    name = "summarizer",
    #'    instruction = paste0(
    #'    "You are an agent designed to summarise ",
    #'    "a given text into 3 distinct bullet points."
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  translator <- Agent$new(
    #'    name = "translator",
    #'    instruction = "Your role is to translate a text from English to German",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent$register_agents(c(researcher, summarizer, translator))
    #'
    #'  lead_agent$agents
    #'
    #'  lead_agent$clear_agents()
    #'
    #'  lead_agent$agents
    #'

    clear_agents = function() {
      self$agents <- list()
    },

    #' @description
    #' Remove registered agents by IDs
    #' @param agent_ids The Agent ID to remove from the registered Agents
    #' @examples
    #'   # An API KEY is required in order to invoke the agents
    #'   openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #'  researcher <- Agent$new(
    #'    name = "researcher",
    #'    instruction = paste0(
    #'    "You are a research assistant. ",
    #'    "Your job is to answer factual questions with detailed and accurate information. ",
    #'    "Do not answer with more than 2 lines"
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  summarizer <- Agent$new(
    #'    name = "summarizer",
    #'    instruction = "You are agent designed to summarise a given text into 3 distinct bullet points.",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  translator <- Agent$new(
    #'    name = "translator",
    #'    instruction = "Your role is to translate a text from English to German",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent$register_agents(c(researcher, summarizer, translator))
    #'
    #'  lead_agent$agents
    #'
    #'  # deleting the translator agent
    #'
    #'  id_translator_agent <- translator$agent_id
    #'
    #'  lead_agent$remove_agents(id_translator_agent)
    #'
    #'  lead_agent$agents
    #'
    remove_agents = function(agent_ids) {

      checkmate::assert_character(agent_ids, any.missing = FALSE)
      self$agents <- Filter(function(a) !(a$agent_id %in% agent_ids), self$agents)

    },

    #' @description
    #' Register one or more agents for delegation.
    #' @param agents A vector of `Agent` objects to register.
    #' @examples
    #'   # An API KEY is required in order to invoke the agents
    #'   openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #'  researcher <- Agent$new(
    #'    name = "researcher",
    #'    instruction = paste0(
    #'    "You are a research assistant. ",
    #'    "Your job is to answer factual questions with detailed and accurate information. ",
    #'    "Do not answer with more than 2 lines"
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  summarizer <- Agent$new(
    #'    name = "summarizer",
    #'    instruction = "You are agent designed to summarise a given text into 3 distinct bullet points.",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  translator <- Agent$new(
    #'    name = "translator",
    #'    instruction = "Your role is to translate a text from English to German",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent$register_agents(c(researcher, summarizer, translator))
    #'
    #'  lead_agent$agents
    register_agents = function(agents) {

      length_agents <- length(self$agents)

      for (i in seq_along(agents)) {
        agent <- agents[[i]]
        self$agents[[length_agents + i]] <- agent
      }

      cli::cli_alert_success("Agent(s) successfully registered.")

      return(invisible(NULL))

    },

    #' @description
    #' Visualizes the orchestration plan
    #' Each agent node is shown in sequence (left → right), with tooltips showing
    #' the actual prompt delegated to that agent.
    visualize_plan = function() {

      plan <- self$plan

      if (length(plan) == 0) {
        cli::cli_abort("No plan found, generate one first")
      }

      nodes <- paste0(
        "A", seq_along(plan),
        " [label='", vapply(plan, `[[`, "", "agent_name"),
        "', tooltip='", gsub("'", "\\\\'", vapply(plan, `[[`, "", "prompt")),
        "', shape=box, style=filled, fillcolor=lightblue, fontname='Helvetica'];"
      )

      edges <- paste0(
        "A", seq_len(length(plan) - 1),
        " -> A", seq_len(length(plan) - 1) + 1,
        " [arrowhead=normal];"
      )

      graph_code <- paste0(
        "digraph workflow {
      graph [rankdir=LR, splines=true, overlap=false];
      node [shape=box, style=filled, fillcolor=lightblue, fontname='Helvetica', fontsize=12];
      edge [color=gray50, arrowsize=0.8];
      ", paste(c(nodes, edges), collapse = "\n"), "
    }"
      )

      DiagrammeR::grViz(graph_code)
    },

    #' @description
    #' Executes the full prompt pipeline: decomposition → delegation → invocation.
    #' @param prompt The complex user instruction to process.
    #' @param force_regenerate_plan If TRUE, regenerate a plan even if one exists,
    #' defaults to FALSE.
    #' @return The final response (from the last agent in the sequence).
    #' @examples \dontrun{
    #'  # An API KEY is required in order to invoke the agents
    #'   openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #'  researcher <- Agent$new(
    #'    name = "researcher",
    #'    instruction = paste0(
    #'    "You are a research assistant. ",
    #'    "Your job is to answer factual questions with detailed ",
    #'    "and accurate information. Do not answer with more than 2 lines"
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  summarizer <- Agent$new(
    #'    name = "summarizer",
    #'    instruction = "You are agent designed to summarise a given text into 3 distinct bullet points.",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  translator <- Agent$new(
    #'    name = "translator",
    #'    instruction = "Your role is to translate a text from English to German",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent$register_agents(c(researcher, summarizer, translator))
    #'
    #'  lead_agent$invoke(
    #'  paste0(
    #'   "Describe the economic situation in Algeria in 3 sentences. ",
    #'   "Answer in German"
    #'   )
    #'  )
    #' }

    invoke = function(prompt, force_regenerate_plan = FALSE) {

      checkmate::assert_character(prompt)
      checkmate::assert_flag(force_regenerate_plan)

      if (length(self$agents) == 0) {

        err_msg <- paste0(
          "No Agent has been assigned yet to the LeadAgent. ",
          "Use the `registre_agents` methods to assign Agents"
        )

        cli::cli_abort(err_msg)
      }

      prompt_invoke_same_as_plan <- FALSE


      if (!is.null(self$prompt_for_plan) && self$prompt_for_plan == prompt) {
        prompt_invoke_same_as_plan <- TRUE
      }

      current_agents <- lapply(self$agents, function(x) {x$name})
      current_agents <- unlist(current_agents)

      same_agents_used <- all(sort(self$agents_for_plan) == sort(current_agents))

      if (is.null(self$agents_for_plan) || !same_agents_used) {
        prompt_invoke_same_as_plan <- FALSE
      }

      if (!prompt_invoke_same_as_plan || length(self$plan) == 0 || force_regenerate_plan) {
        cli::cli_h2("Generating new plan")
        prompts_res <- self$generate_plan(prompt)
      } else {
        cli::cli_h2("Using existing plan")
        prompts_res <- self$plan
      }

      for (i in seq_along(prompts_res)) {
        prompts_res[[i]]$response <- NA
      }

      self$agents_interaction <- prompts_res

      for (i in seq_along(self$agents_interaction)) {
        step <- self$agents_interaction[[i]]

        idx <- which(sapply(self$agents, function(agent) agent$agent_id == step$agent_id))
        selected_agent <- self$agents[[idx]]

        prompt_to_consider <- step$prompt
        if (i > 1) {
          prev_resp <- self$agents_interaction[[i - 1]]$response
          prompt_to_consider <- paste(
            "\n\nBefore answering consider the previous response:\n", prev_resp,
            "\n\n--- Task ---\n", prompt_to_consider
          )
        }

        response <- selected_agent$invoke(prompt_to_consider)
        step$response <- response
        step$edited_by_hitl <- FALSE
        self$agents_interaction[[i]] <- step

        if (i %in% self$hitl_steps && !is.null(self$hitl_steps)) {
          private$.human_confirm(i)
        }
      }

      self$agents_interaction[[length(self$agents_interaction)]]$response

    },

    #' @description
    #' Generates a task execution plan without executing the subtasks.
    #' It returns a structured list containing the subtask, the selected agent, and metadata.
    #' @param prompt A complex instruction to be broken into subtasks.
    #' @return A list of lists containing agent_id, agent_name, model_name, model_provider, and the assigned prompt.
    #' @examples \dontrun{
    #'  # An API KEY is required in order to invoke the agents
    #'   openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #'  researcher <- Agent$new(
    #'    name = "researcher",
    #'    instruction = paste0(
    #'    "You are a research assistant. Your job is to answer factual questions ",
    #'    "with detailed and accurate information. Do not answer with more than 2 lines"
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  summarizer <- Agent$new(
    #'    name = "summarizer",
    #'    instruction = "You are agent designed to summarise a given text into 3 distinct bullet points.",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  translator <- Agent$new(
    #'    name = "translator",
    #'    instruction = "Your role is to translate a text from English to German",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent$register_agents(c(researcher, summarizer, translator))
    #'
    #'  lead_agent$generate_plan(
    #'  paste0(
    #'   "Describe the economic situation in Algeria in 3 sentences. ",
    #'   "Answer in German"
    #'   )
    #'  )
    #' }
    generate_plan = function(prompt) {

      if (length(self$agents) == 0) {
        cli::cli_abort("No agents registered. Use `register_agents()` to add sub-agents before generating a plan.")
      }

      subtasks <- private$.analyze_prompt(prompt)

      plan <- lapply(subtasks, function(task) {
        agent_id <- private$.match_agent_to_task(task)

        idx <- which(sapply(self$agents, function(agent) agent$agent_id == agent_id))
        selected_agent <- self$agents[[idx]]

        list(
          agent_id = agent_id,
          agent_name = selected_agent$name,
          model_provider = selected_agent$model_provider,
          model_name = selected_agent$model_name,
          prompt = task
        )
      })

      cli::cli_alert_success("Plan successfully generated.")

      self$plan <- plan

      self$prompt_for_plan <- prompt

      agents_names <- lapply(self$agents, function(x) {x$name})

      agents_names <- unlist(agents_names)

      self$agents_for_plan <- agents_names

      return(plan)
    },

    #' @description
    #' Broadcasts a prompt to all registered agents and collects their responses.
    #' This does not affect the main agent orchestration logic or history.
    #' @param prompt A user prompt to send to all agents.
    #' @return A list of responses from all agents.
    #' @examples \dontrun{
    #'  # An API KEY is required in order to invoke the agents
    #' openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #' openai_4_1 <- ellmer::chat(
    #'   name = "openai/gpt-4.1",
    #'   api_key = Sys.getenv("OPENAI_API_KEY"),
    #'   echo = "none"
    #' )
    #'
    #' openai_4_1_agent <- Agent$new(
    #'   name = "openai_4_1_agent",
    #'   instruction = "You are an AI assistant. Answer in 1 sentence max.",
    #'   llm_object = openai_4_1
    #' )
    #'
    #' openai_4_1_nano <- ellmer::chat(
    #'   name = "openai/gpt-4.1-nano",
    #'   api_key = Sys.getenv("OPENAI_API_KEY"),
    #'   echo = "none"
    #' )
    #'
    #' openai_4_1_nano_agent <- Agent$new(
    #'   name = "openai_4_1_nano_agent",
    #'   instruction = "You are an AI assistant. Answer in 1 sentence max.",
    #'   llm_object = openai_4_1_nano
    #'   )
    #'
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #' lead_agent$register_agents(c(openai_4_1_agent, openai_4_1_nano_agent))
    #' lead_agent$broadcast(
    #'   prompt = paste0(
    #'     "If I were Algerian, which song would I like to sing ",
    #'     "when running under the rain? how about a flower?"
    #'   )
    #'   )
    #' }
    broadcast = function(prompt) {
      checkmate::assert_string(prompt)

      if (length(self$agents) == 0) {
        cli::cli_abort("No agents have been registered. Use `register_agents()` first.")
      }

      responses <- lapply(self$agents, function(agent) {
        response <- agent$invoke(prompt)
        list(
          agent_id = agent$agent_id,
          agent_name = agent$name,
          model_provider = agent$model_provider,
          model_name = agent$model_name,
          response = response
        )
      })

      self$broadcast_history[[length(self$broadcast_history) + 1]] <- list(
        prompt = prompt,
        responses = responses
      )

      return(responses)
    },

    #' @description
    #' Set Human In The Loop (HITL) interaction at determined steps within the workflow
    #' @param steps At which steps the Human In The Loop is required?
    #' @return A list of responses from all agents.
    #' @examples \dontrun{
    #'  # An API KEY is required in order to invoke the agents
    #'   openai_4_1_mini <- ellmer::chat(
    #'     name = "openai/gpt-4.1-mini",
    #'     api_key = Sys.getenv("OPENAI_API_KEY"),
    #'     echo = "none"
    #'   )
    #'  researcher <- Agent$new(
    #'    name = "researcher",
    #'    instruction = paste0(
    #'     "You are a research assistant. ",
    #'     "Your job is to answer factual questions with detailed and accurate information. ",
    #'     "Do not answer with more than 2 lines"
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  summarizer <- Agent$new(
    #'    name = "summarizer",
    #'    instruction = paste0(
    #'    "You are agent designed to summarise a give text ",
    #'    "into 3 distinct bullet points."
    #'    ),
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  translator <- Agent$new(
    #'    name = "translator",
    #'    instruction = "Your role is to translate a text from English to German",
    #'    llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #'  )
    #'
    #'  lead_agent$register_agents(c(researcher, summarizer, translator))
    #'
    #'  # setting a human in the loop in step 2
    #'  lead_agent$set_hitl(1)
    #'
    #'  # The execution will stop at step 2 and a human will be able
    #'  # to either accept the answer, modify it or stop the execution of
    #'  # the workflow
    #'
    #'  lead_agent$invoke(
    #'  paste0(
    #'   "Describe the economic situation in Algeria in 3 sentences. ",
    #'   "Answer in German"
    #'   )
    #'  )
    #' }
    set_hitl = function(steps) {
      checkmate::assert_integerish(steps, lower = 1, any.missing = FALSE)
      self$hitl_steps <- unique(as.integer(steps))

      steps_chr <- as.character(steps)
      steps_chr <- toString(steps_chr)

      cli::cli_alert_success("HITL successfully set at step(s) {steps_chr}.")

    },

    #' @description
    #' The Lead Agent send a prompt to its registered agents and choose the best response
    #' from the agents' responses
    #' @param prompt The prompt to send to the registered agents
    #' @return A list of responses from all agents, including the chosen response
    #' @examples \dontrun{
    #' openai_4_1_mini <- ellmer::chat(
    #'   name = "openai/gpt-4.1-mini",
    #'   api_key = Sys.getenv("OPENAI_API_KEY"),
    #'   echo = "none"
    #' )
    #' openai_4_1 <- ellmer::chat(
    #'   name = "openai/gpt-4.1",
    #'   api_key = Sys.getenv("OPENAI_API_KEY"),
    #'   echo = "none"
    #' )
    #'
    #' stylist <- Agent$new(
    #'   name = "stylist",
    #'   instruction = "You are an AI assistant. Answer in 1 sentence max.",
    #'   llm_object = openai_4_1
    #' )
    #'
    #' openai_4_1_nano <- ellmer::chat(
    #'   name = "openai/gpt-4.1-nano",
    #'   api_key = Sys.getenv("OPENAI_API_KEY"),
    #'   echo = "none"
    #' )
    #'
    #' stylist2 <- Agent$new(
    #'   name = "stylist2",
    #'   instruction = "You are an AI assistant. Answer in 1 sentence max.",
    #'   llm_object = openai_4_1_nano
    #' )
    #'
    #' lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #' )
    #'
    #' lead_agent$register_agents(c(stylist, stylist2))
    #'
    #' lead_agent$judge_and_choose_best_response("what's the best way to war a kalvin klein shirt?")
    #'
    #' }
    judge_and_choose_best_response = function(prompt) {

      checkmate::assert_string(prompt)

      if (length(self$agents) == 0) {
        cli::cli_abort("No agents registered. Use `register_agents()` first.")
      }

      proposals <- lapply(self$agents, function(agent) {
        resp <- agent$invoke(prompt)
        list(
          agent_id = agent$agent_id,
          agent_name = agent$name,
          response = resp
        )
      })

      responses_summary <- paste(
        vapply(proposals, function(x) {x$response}, character(1)),
        collapse = "\n------------\n"
      )

      judge_prompt <- glue::glue(
        "The following prompt was previously executed: {prompt}. ",
        "We got back the following responses from several agents: ",
        "Each response is separated by a ------------",
        "\nResponses:\n\n",
        "<<<<",
        responses_summary,
        ">>>>",
        "\n",
        "\nChoose the best response according to initial prompt.",
        "\nReturn ONLY the final response text. Nothing else. Do not talk. Just return the best response"
      )

      result <- self$llm_object$chat(judge_prompt)

      final_result <- list(
        proposals = proposals,
        chosen_response = result
      )

      return(final_result)

    },

    #' @description
    #' Facilitates a collaborative dialog between two agents to refine a response.
    #' The agents take turns building on each other's responses until they reach
    #' consensus or the maximum iterations are reached. Agents can signal consensus
    #' by starting their response with "CONSENSUS:". If max iterations is reached
    #' without consensus, the lead agent synthesizes a final response.
    #' @param prompt The initial task or question for the agents to discuss.
    #' @param agent_1_id The ID of the first agent to participate in the dialog.
    #' @param agent_2_id The ID of the second agent to participate in the dialog.
    #' @param max_iterations Maximum number of back-and-forth exchanges (default: 5).
    #' @return A list containing the final response, consensus status, and complete dialog history.
    #' @examples \dontrun{
    #' # An API KEY is required in order to invoke the agents
    #' openai_4_1_mini <- ellmer::chat(
    #'   name = "openai/gpt-4.1-mini",
    #'   api_key = Sys.getenv("OPENAI_API_KEY"),
    #'   echo = "none"
    #' )
    #' openai_4_1_nano <- ellmer::chat(
    #'   name = "openai/gpt-4.1-nano",
    #'   api_key = Sys.getenv("OPENAI_API_KEY"),
    #'   echo = "none"
    #' )
    #'
    #' creative_writer <- Agent$new(
    #'   name = "creative_writer",
    #'   instruction = "You are a creative writer. Focus on engaging storytelling.",
    #'   llm_object = openai_4_1_nano
    #' )
    #'
    #' editor <- Agent$new(
    #'   name = "editor",
    #'   instruction = "You are an editor. Focus on clarity and conciseness.",
    #'   llm_object = openai_4_1_mini
    #' )
    #'
    #' lead_agent <- LeadAgent$new(
    #'   name = "Leader",
    #'   llm_object = openai_4_1_mini
    #' )
    #'
    #' lead_agent$register_agents(c(creative_writer, editor))
    #'
    #' result <- lead_agent$agents_dialog(
    #'   prompt = "Write a compelling opening sentence for a sci-fi novel.",
    #'   agent_1_id = creative_writer$agent_id,
    #'   agent_2_id = editor$agent_id,
    #'   max_iterations = 3
    #' )
    #'
    #' # Access the final response
    #' result$final_response
    #'
    #' # View the dialog history
    #' result$dialog_history
    #' }
    agents_dialog = function(prompt, agent_1_id, agent_2_id, max_iterations = 5) {

      checkmate::assert_string(prompt)
      checkmate::assert_string(agent_1_id)
      checkmate::assert_string(agent_2_id)
      checkmate::assert_int(max_iterations, lower = 1)

      if (length(self$agents) == 0) {
        cli::cli_abort("No agents registered. Use `register_agents()` first.")
      }

      if (agent_1_id == agent_2_id) {
        cli::cli_abort("Agent 1 and Agent 2 must be different agents.")
      }

      agent_ids <- vapply(self$agents, function(a) a$agent_id, character(1))

      if (!agent_1_id %in% agent_ids) {
        cli::cli_abort("Agent 1 with ID '{agent_1_id}' not found in registered agents.")
      }

      if (!agent_2_id %in% agent_ids) {
        cli::cli_abort("Agent 2 with ID '{agent_2_id}' not found in registered agents.")
      }

      idx_1 <- which(agent_ids == agent_1_id)
      idx_2 <- which(agent_ids == agent_2_id)

      agent_1 <- self$agents[[idx_1]]
      agent_2 <- self$agents[[idx_2]]

      cli::cli_h2("Starting agent dialog")
      cli::cli_text("Agent 1: {.strong {agent_1$name}}")
      cli::cli_text("Agent 2: {.strong {agent_2$name}}")
      cli::cli_text("Max iterations: {max_iterations}")

      dialog_history <- list()
      current_response <- NULL
      consensus_reached <- FALSE
      final_response <- NULL

      for (i in seq_len(max_iterations)) {

        cli::cli_alert_info("Iteration {i} - {agent_1$name} responding...")

        if (is.null(current_response)) {
          prompt_1 <- prompt
        } else {
          prompt_1 <- paste0(
            "REMEMBER YOUR ROLE: ", agent_1$instruction, "\n\n",
            "You are in a collaborative negotiation to solve this task: ", prompt, "\n\n",
            "The other agent just proposed:\n",
            current_response, "\n\n",
            "CRITICAL: Evaluate their proposal against YOUR specific role, requirements, and constraints described above. ",
            "Does it fully align with YOUR requirements? Does it respect YOUR constraints? ",
            "If there are ANY conflicts with your role, concerns about their approach, or areas where your perspective differs, ",
            "you MUST propose your counterproposal that better addresses YOUR requirements. ",
            "Do NOT simply accept their proposal if it conflicts with your role or constraints. ",
            "Only respond with 'CONSENSUS: ' followed by the final solution if their proposal genuinely ",
            "satisfies BOTH your requirements AND theirs, with no compromises to your constraints. ",
            "Otherwise, continue negotiating."
          )
        }

        response_1 <- agent_1$invoke(prompt_1)

        dialog_history[[length(dialog_history) + 1]] <- list(
          iteration = i,
          agent_id = agent_1$agent_id,
          agent_name = agent_1$name,
          response = response_1
        )

        if (grepl("^CONSENSUS:", response_1, ignore.case = TRUE)) {
          cli::cli_alert_success("Consensus reached by {agent_1$name} at iteration {i}!")
          consensus_reached <- TRUE
          final_response <- sub("^CONSENSUS:\\s*", "", response_1, ignore.case = TRUE)
          break
        }

        current_response <- response_1

        cli::cli_alert_info("Iteration {i} - {agent_2$name} responding...")

        prompt_2 <- paste0(
          "REMEMBER YOUR ROLE: ", agent_2$instruction, "\n\n",
          "You are in a collaborative negotiation to solve this task: ", prompt, "\n\n",
          "The other agent just proposed:\n",
          current_response, "\n\n",
          "CRITICAL: Evaluate their proposal against YOUR specific role, requirements, and constraints described above. ",
          "Does it fully align with YOUR requirements? Does it respect YOUR constraints? ",
          "If there are ANY conflicts with your role, concerns about their approach, or areas where your perspective differs, ",
          "you MUST propose your counterproposal that better addresses YOUR requirements. ",
          "Do NOT simply accept their proposal if it conflicts with your role or constraints. ",
          "Only respond with 'CONSENSUS: ' followed by the final solution if their proposal genuinely ",
          "satisfies BOTH your requirements AND theirs, with no compromises to your constraints. ",
          "Otherwise, continue negotiating."
        )

        response_2 <- agent_2$invoke(prompt_2)

        dialog_history[[length(dialog_history) + 1]] <- list(
          iteration = i,
          agent_id = agent_2$agent_id,
          agent_name = agent_2$name,
          response = response_2
        )

        if (grepl("^CONSENSUS:", response_2, ignore.case = TRUE)) {
          cli::cli_alert_success("Consensus reached by {agent_2$name} at iteration {i}!")
          consensus_reached <- TRUE
          final_response <- sub("^CONSENSUS:\\s*", "", response_2, ignore.case = TRUE)
          break
        }

        current_response <- response_2
      }

      if (!consensus_reached) {
        cli::cli_alert_warning("Max iterations reached without explicit consensus.")
        cli::cli_alert_info("Using lead agent to synthesize final response...")

        history_text <- paste(
          vapply(dialog_history, function(h) {
            paste0("[", h$agent_name, "]: ", h$response)
          }, character(1)),
          collapse = "\n\n"
        )

        synthesis_prompt <- paste0(
          "Original task: ", prompt, "\n\n",
          "Two agents have discussed this task. Here is their conversation:\n\n",
          history_text, "\n\n",
          "Based on their discussion, synthesize and provide the best final answer to the original task. ",
          "CRITICAL: Return ONLY the final answer itself, as if you were directly answering the original task. ",
          "DO NOT write instructions, DO NOT mention the agents or their discussion, ",
          "DO NOT use phrases like 'Write...', 'The final answer is...', or 'Based on...'. ",
          "Just provide the direct answer to the task."
        )

        final_response <- self$llm_object$chat(synthesis_prompt)
      }

      result <- list(
        prompt = prompt,
        agent_1_name = agent_1$name,
        agent_2_name = agent_2$name,
        consensus_reached = consensus_reached,
        iterations_used = length(dialog_history),
        dialog_history = dialog_history,
        final_response = final_response
      )

      self$dialog_history[[length(self$dialog_history) + 1]] <- result

      cli::cli_alert_success("Dialog completed.")

      return(result)

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

      agent_ids <- unlist(lapply(self$agents, function(agent) agent$agent_id))

      if (!agent_id %in% agent_ids) {
        cli::cli_abort("LLM returned invalid agent_id: ", agent_id)
      }

      self$llm_object$set_system_prompt(value = base_system_prompt)

      return(agent_id)

    },

    .human_confirm = function(step_index) {

      step <- self$agents_interaction[[step_index]]

      cli::cli_rule(left = "HITL Step {step_index}")
      cli::cli_text("Agent: {.strong {step$agent_name}}")
      cli::cli_alert_info("Prompt:")
      cli::cli_text("{.italic {step$prompt}}")
      cli::cli_alert_info("Response:")
      cli::cli_text("{.italic {step$response}}")

      cli::cli_text(cli::cli_ul(c(
        "[1] Continue with this response ---",
        "[2] Edit the response ---",
        "[3] Stop the workflow ---"
      )))

      repeat {
        answer <- readline("Your choice [1/2/3]: ")
        if (nzchar(answer) && answer %in% c("1", "2", "3")) break
        cli::cli_alert_warning("Invalid input. Please enter 1, 2, or 3.")
      }

      if (answer == "2") {
        new_response <- readline("(->) Enter edited response: ")
        step$response <- new_response
        step$edited_by_hitl <- TRUE
        cli::cli_alert_success("Response updated.")
      } else if (answer == "3") {
        cli::cli_alert_danger("Workflow manually stopped at step {step_index}.")
        cli::cli_abort("HITL: Execution stopped by user.")
      } else {
        cli::cli_alert_success("Continuing with original response.")
      }

      self$agents_interaction[[step_index]] <- step
    }
  )
)

