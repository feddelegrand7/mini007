
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

`mini007` provides a lightweight and extensible framework for
multi-agents orchestration processes capable of decomposing complex
tasks and assigning them to specialized agents.

Each `agent` is an extension of an `ellmer` object. `mini007` relies
heavily on the excellent `ellmer` package but aims to make it easy to
create a process where multiple specialized agents help each other
sequentially in order to execute a task.

`mini007` provides two types of agents:

- A normal `Agent` containing a name and an instruction,
- and a `LeadAgent` which will take a complex prompt, split it, assign
  to the adequate agents and retrieve the response.

#### Highlights

🧠 Memory and identity for each agent via `uuid` and message history.

⚙️ Built-in task decomposition and delegation via `LLM`.

🔄 Agent-to-agent orchestration with result chaining.

🌐 Compatible with any chat model supported by `ellmer`.

🧑 Possibility to set a Human In The Loop (`HITL`) at various execution
steps

You can install `mini007` from `CRAN` with:

``` r
install.packages("mini007")
```

The documentation is available
[here](https://feddelegrand7.github.io/mini007/)

## Workflows

A `Workflow` lets you wire multiple agents (or plain R functions) into a
sequential pipeline. Each **Station** receives the output of the
previous one as its input, and **Routes** define which Station comes
next — optionally gated by a condition on the output.

### Example 1 — Linear pipeline of agents

The most common pattern: a fixed sequence of specialised agents, each
refining the result of the previous one.

``` r
library(mini007)
library(ellmer)

# Three specialised agents
researcher <- Agent$new(
  name       = "Researcher",
  llm_object = chat_openai(model = "gpt-4.1-mini"),
  instruction = "You gather and summarise factual information on a topic."
)

writer <- Agent$new(
  name       = "Writer",
  llm_object = chat_openai(model = "gpt-4.1-mini"),
  instruction = "You turn research notes into a clear, engaging paragraph."
)

editor <- Agent$new(
  name       = "Editor",
  llm_object = chat_openai(model = "gpt-4.1-mini"),
  instruction = "You polish text for grammar, style, and conciseness."
)

# Build the workflow
wf <- Workflow$new(
  name        = "article-pipeline",
  description = "Research → Write → Edit",
  use_cache   = TRUE          # cache each station's output
)

wf$add_station("research", researcher)
wf$add_station("write",    writer)
wf$add_station("edit",     editor)

wf$add_route("research", "write")
wf$add_route("write",    "edit")

wf$set_entry("research")

# Run — each station's output feeds the next
final <- wf$run("The impact of sleep deprivation on decision-making")
cat(final)
```

Because `use_cache = TRUE`, calling `wf$run()` again with the same
prompt skips re-invoking any LLM and returns cached results instantly.
Call `wf$clear_cache()` whenever you want a fresh run.

------------------------------------------------------------------------

### Example 2 — Mixing agents with plain R functions

Stations do not have to be agents. Any `function(input)` that returns a
character string is a valid handler, making it easy to inject
pre-processing or post-processing steps without spinning up an LLM.

``` r
library(mini007)
library(ellmer)

summariser <- Agent$new(
  name        = "Summariser",
  llm_object  = chat_openai(model = "gpt-4.1-mini"),
  instruction = "Summarise the following text in three bullet points."
)

# Plain function stations — no LLM needed
clean_input <- function(text) {
  trimws(gsub("\\s+", " ", text))        # collapse whitespace
}

add_header <- function(text) {
  paste0("## Summary\n\n", text)
}

wf <- Workflow$new("clean-summarise-format")

wf$add_station("clean",     clean_input, description = "Normalise whitespace")
wf$add_station("summarise", summariser,  description = "LLM bullet-point summary")
wf$add_station("format",    add_header,  description = "Add markdown header")

wf$add_route("clean",     "summarise")
wf$add_route("summarise", "format")

result <- wf$run("  This is   some   messy    input text...  ")
cat(result)
```

------------------------------------------------------------------------

### Example 3 — Conditional routing

Routes can carry a `condition` — a function that receives the current
Station’s output and returns `TRUE` or `FALSE`. Conditional routes are
evaluated first; the first one whose condition holds is followed. An
unconditional route acts as the default fallback.

``` r
library(mini007)
library(ellmer)

classifier <- Agent$new(
  name        = "Classifier",
  llm_object  = chat_openai(model = "gpt-4.1-mini"),
  instruction = 'Classify the sentiment of the text. Reply with exactly one word: "positive" or "negative".'
)

pos_responder <- Agent$new(
  name        = "PositiveResponder",
  llm_object  = chat_openai(model = "gpt-4.1-mini"),
  instruction = "Write a warm, enthusiastic reply to the following positive feedback."
)

neg_responder <- Agent$new(
  name        = "NegativeResponder",
  llm_object  = chat_openai(model = "gpt-4.1-mini"),
  instruction = "Write an empathetic, solution-focused reply to the following negative feedback."
)

wf <- Workflow$new("sentiment-router")

wf$add_station("classify",      classifier)
wf$add_station("reply-positive", pos_responder)
wf$add_station("reply-negative", neg_responder)

# Conditional routes — evaluated against the classifier's output
wf$add_route(
  from      = "classify",
  to        = "reply-positive",
  condition = function(out) grepl("positive", tolower(out))
)
wf$add_route(
  from      = "classify",
  to        = "reply-negative",
  condition = function(out) grepl("negative", tolower(out))
)

wf$set_entry("classify")

cat(wf$run("I absolutely love this product!"))
cat(wf$run("Very disappointed with the quality."))
```

------------------------------------------------------------------------

### Example 4 — Wrapping a workflow as an agent

`$as_agent()` converts any `Workflow` into a `WorkflowAgent`. The result
exposes the same `$invoke()` interface as a regular `Agent`, so it can
be:

- registered with a `LeadAgent` as one of its sub-agents, or
- embedded as a Station handler inside another `Workflow`.

``` r
library(mini007)
library(ellmer)

# --- inner workflow: research pipeline ---
inner_wf <- Workflow$new("research-pipeline")

inner_wf$add_station("fetch",     function(q) paste("Facts about:", q))
inner_wf$add_station("summarise", Agent$new(
  name        = "Summariser",
  llm_object  = chat_openai(model = "gpt-4.1-mini"),
  instruction = "Summarise the provided facts concisely."
))

inner_wf$add_route("fetch", "summarise")

# Wrap as an agent
research_agent <- inner_wf$as_agent(
  name        = "ResearchAgent",
  instruction = "An agent that fetches and summarises facts on any topic."
)

# --- outer workflow: use the wrapped agent as a station ---
outer_wf <- Workflow$new("full-pipeline")

outer_wf$add_station("research", research_agent)   # WorkflowAgent used as handler
outer_wf$add_station("present",  Agent$new(
  name        = "Presenter",
  llm_object  = chat_openai(model = "gpt-4.1-mini"),
  instruction = "Turn the summary into a polished short report."
))

outer_wf$add_route("research", "present")
outer_wf$set_entry("research")

cat(outer_wf$run("quantum computing"))

# --- or register the WorkflowAgent with a LeadAgent ---
lead <- LeadAgent$new(
  name       = "Lead",
  llm_object = chat_openai(model = "gpt-4.1-mini")
)

lead$register_agents(list(research_agent))
lead$invoke("Tell me about photosynthesis")
```

------------------------------------------------------------------------

### Visualising a workflow

Call `$visualize()` on any `Workflow` to render an interactive directed
graph. Stations appear as rounded boxes, conditional routes as dashed
arrows, and the entry Station is marked with a green **START** circle.

``` r
wf$visualize()
```

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
