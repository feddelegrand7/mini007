
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mini007 <a><img src='man/figures/mini007cute.png' align="right" height="200" /></a>

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/mini007)](https://CRAN.R-project.org/package=mini007)
[![R
badge](https://img.shields.io/badge/Build%20with-♥%20and%20R-blue)](https://github.com/feddelegrand7/mini007)
[![metacran
downloads](https://cranlogs.r-pkg.org/badges/mini007)](https://cran.r-project.org/package=mini007)
[![metacran
downloads](https://cranlogs.r-pkg.org/badges/grand-total/mini007)](https://cran.r-project.org/package=mini007)

<!-- badges: end -->

`mini007` is a lightweight and extensible R framework for building
multi-agent AI systems. It lets you create specialised LLM-backed
agents, orchestrate them through a lead agent that decomposes and
delegates complex tasks, and wire them together into explicit sequential
pipelines called Workflows, all built on top of the excellent
[`ellmer`](https://ellmer.tidyverse.org/) package and compatible with
any chat model it supports.

## Key components

``` r
library(mini007)

retrieve_open_ai_credential <- function() {
  Sys.getenv("OPENAI_API_KEY")
}

llm <- ellmer::chat(
  name        = "openai/gpt-4.1-mini",
  credentials = retrieve_open_ai_credential,
  echo        = "none"
)
```

### `Agent` a stateful LLM-backed worker

An `Agent` wraps an `ellmer` chat object and adds identity, persistent
message history, budget tracking, and tool support.

``` r
researcher <- Agent$new(
  name        = "researcher",
  instruction = "You are a research assistant. Answer factual questions concisely.",
  llm_object  = llm
)

researcher$invoke("What is the capital of Algeria?")
```

Agents remember the full conversation, so follow-up questions work
naturally:

``` r
researcher$invoke("And what is its population?")
```

Key capabilities:

- **Persistent memory**: full message history with `$messages`, trimming
  via `$keep_last_n_messages()`, export/import via
  `$export_messages_history()` / `$load_messages_history()`.
- **Context sharing**: pass recent messages from one agent to another
  with `$share_context_with(other_agent)`.
- **Budget control**: set a USD spending limit with `$set_budget()` and
  choose a policy (`"abort"`, `"warn"`, or `"ask"`) via
  `$set_budget_policy()`.
- **Tools**: register `ellmer` tool objects with `$register_tools()`,
  generate new ones from a natural-language description with
  `$generate_and_register_tool()`.
- **R code generation**: ask an agent to write, validate, and optionally
  execute R code with `$generate_execute_r_code()`.
- **Response validation**: verify an agent’s output against criteria
  using `$validate_response()`.
- **Cloning**: create an independent copy of an agent (new UUID, shared
  instruction) with `$clone_agent()`.

------------------------------------------------------------------------

### `LeadAgent` multi-agent orchestration

A `LeadAgent` extends `Agent` with the ability to decompose a complex
prompt into subtasks and automatically delegate each one to the most
suitable registered agent.

``` r
summariser <- Agent$new(
  name        = "summariser",
  instruction = "Summarise text into three bullet points.",
  llm_object  = llm
)

translator <- Agent$new(
  name        = "translator",
  instruction = "Translate text from English to German.",
  llm_object  = llm
)

lead <- LeadAgent$new(name = "Lead", llm_object = llm)
lead$register_agents(c(summariser, translator))

lead$invoke("Summarise the history of the Roman Empire, then translate it into German.")
```

Key capabilities:

- **Plan generation**: preview which agent handles which subtask before
  running with `$generate_plan()`.
- **Plan visualisation**: render the orchestration as a directed graph
  with `$visualize_plan()`.
- **Broadcasting**: send the same prompt to every registered agent and
  collect all responses with `$broadcast()`.
- **Judging**: let the lead agent pick the best response from all
  registered agents with `$judge_and_choose_best_response()`.
- **Agent dialog**: run an iterative negotiation between two agents
  until they reach consensus with `$agents_dialog()`.
- **Human In The Loop (HITL)**: pause execution at specific steps so a
  human can review, edit, or abort the response with `$set_hitl(steps)`.

------------------------------------------------------------------------

### `Workflow` explicit sequential pipelines

A `Workflow` lets you build a predefined pipeline of **Stations**
connected by **Routes**. Each Station’s output becomes the next one’s
input. Unlike `LeadAgent`, the execution path is fully explicit, you
control the order and branching logic.

``` r
wf <- Workflow$new(name = "article-pipeline")

wf$add_station("research", Agent$new(
  name        = "researcher",
  instruction = "Gather concise facts on the topic.",
  llm_object  = llm
))
wf$add_station("write", Agent$new(
  name        = "writer",
  instruction = "Turn the facts into an engaging paragraph.",
  llm_object  = llm
))
wf$add_station("edit", Agent$new(
  name        = "editor",
  instruction = "Polish the paragraph for grammar and clarity.",
  llm_object  = llm
))

wf$add_route("research", "write")
wf$add_route("write",    "edit")

wf$run("The history of the printing press")
```

Key capabilities:

- **Mixed handlers**: Stations accept `Agent` objects, `WorkflowAgent`
  objects, or plain R `function`s, making it easy to mix LLM calls with
  deterministic pre/post-processing steps.
- **Conditional routing**: `add_route(from, to, condition)` gates a
  route on a function of the previous Station’s output, enabling
  branching pipelines.
- **Caching**: with `use_cache = TRUE` (default), each Station’s result
  is stored by `(name, input)`. Re-running the same input serves the
  cache instantly. Use `$clear_cache()` to reset.
- **Wrapping as an agent**: `$as_agent()` converts any `Workflow` into a
  `WorkflowAgent` that can be registered with a `LeadAgent` or embedded
  as a Station inside another `Workflow`.
- **Visualisation**: `$visualize()` renders the pipeline as an
  interactive directed graph via `DiagrammeR`.

## Installation

You can install `mini007` from `CRAN` with:

``` r
install.packages("mini007")
```

The documentation is available
[here](https://feddelegrand7.github.io/mini007/)

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
