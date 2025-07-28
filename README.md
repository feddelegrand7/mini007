
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mini007 <a><img src='man/figures/mini007cute.png' align="right" height="200" /></a>

<!-- badges: start -->

<!-- badges: end -->

`mini007` provides a lightweight and extensible framework multi-agents
orchestration processes capable of decomposing complex tasks and
assigning them to specialized agents.

Each `agent` is an extension of an `ellmer` object. `mini007` relies
heavily on the excellent `ellmer` package but aims to make it easy to
create a process where multiple specialized agents help each other in
order to execute a task.

`mini007` provides two types of agents:

- A normal `Agent` containing a name and an instruction,
- and a `LeadAgent` which will take a complex prompt, split it, assign
  to the adequate agents and retrieve the response.

#### Highlights

🧠 Memory and identity for each agent via `uuid` and message history.

⚙️ Built-in task decomposition and delegation via `LLM`.

🔄 Agent-to-agent orchestration with result chaining.

🌐 Compatible with any chat model supported by `ellmer`.

You can install the development version of `mini007` like so:

``` r
devtools::install_github("feddelegrand7/mini007")
```

``` r
library(mini007)
```

### Creating an Agent

An Agent is built upon an LLM object created by the `ellmer` package, in
the following examples, we’ll work with the `OpenAI` models, however you
can use any model/combination of models you want:

``` r
# no need to provide the system prompt, it will be set when creating the
# agent (see the 'instruction' parameter)

openai_llm_object <- ellmer::chat_openai(
  model = "gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"), 
  echo = "none"
)
```

After initialising the `ellmer` LLM object, creating the Agent is
straightforward:

``` r
polar_bear_researcher <- Agent$new(
  name = "POLAR BEAR RESEARCHER",
  instruction = "You are an expert in polar bears, you task is to collect information about polar bears.",
  llm_object = openai_llm_object
)
```

Each created Agent has an `agent_id` (among other meta information):

``` r
polar_bear_researcher$agent_id
#> [1] "b2e814d5-8432-4b6f-b4f2-0d66225a11ce"
```

At any time, you can tweak the `llm_object`:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=1 tokens=0/0 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
```

An agent can provide the answer to a prompt using the `invoke` method:

``` r
polar_bear_researcher$invoke("Are polar bears dangerous for humans?")
#> [1] "Yes, polar bears can be dangerous to humans. They are large, powerful predators with strong hunting instincts. While polar bear attacks on humans are relatively rare, when encounters occur, the bears can be aggressive and potentially deadly. Polar bears may see humans as a threat or as prey, especially when food is scarce. It is important to exercise extreme caution when in polar bear habitats, follow safety guidelines, and avoid attracting bears to human settlements or campsites. Proper knowledge and preparedness are essential to minimize risks during polar bear encounters."
```

You can also retrieve a list that displays the history of the agent:

``` r
polar_bear_researcher$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are an expert in polar bears, you task is to collect information about polar bears."
#> 
#> 
#> [[2]]
#> [[2]]$role
#> [1] "user"
#> 
#> [[2]]$content
#> [1] "Are polar bears dangerous for humans?"
#> 
#> 
#> [[3]]
#> [[3]]$role
#> [1] "assistant"
#> 
#> [[3]]$content
#> [1] "Yes, polar bears can be dangerous to humans. They are large, powerful predators with strong hunting instincts. While polar bear attacks on humans are relatively rare, when encounters occur, the bears can be aggressive and potentially deadly. Polar bears may see humans as a threat or as prey, especially when food is scarce. It is important to exercise extreme caution when in polar bear habitats, follow safety guidelines, and avoid attracting bears to human settlements or campsites. Proper knowledge and preparedness are essential to minimize risks during polar bear encounters."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/104 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [104] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous to humans. They are large, powerful predators with strong hunting instincts. While polar bear attacks on humans are relatively rare, when encounters occur, the bears can be aggressive and potentially deadly. Polar bears may see humans as a threat or as prey, especially when food is scarce. It is important to exercise extreme caution when in polar bear habitats, follow safety guidelines, and avoid attracting bears to human settlements or campsites. Proper knowledge and preparedness are essential to minimize risks during polar bear encounters.
```

### Creating a multi-agents orchestraction

We can create as many Agents as we want, the `LeadAgent` will dispatch
the instructions to the agents and provide with the final answer back.

``` r

researcher <- Agent$new(
  name = "researcher",
  instruction = "You are a research assistant. Your job is to answer factual questions with detailed and accurate information. Do not answer with more than 2 lines",
  llm_object = openai_llm_object
)

summarizer <- Agent$new(
  name = "summarizer",
  instruction = "You are agent designed to summarise a give text into 3 distinct bullet points.",
  llm_object = openai_llm_object
)

translator <- Agent$new(
  name = "translator",
  instruction = "Your role is to translate a text from English to German",
  llm_object = openai_llm_object
)

lead_agent <- LeadAgent$new(
  name = "Leader", 
  llm_object = openai_llm_object
)

lead_agent$register_agents(c(researcher, summarizer, translator))

response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
#> Called from: private$.analyze_prompt(prompt)
#> debug at /Users/mohamedelfodilihaddaden/Desktop/gitlab/mini007/R/main.R#257: result <- self$llm_object$chat(prompt)
#> debug at /Users/mohamedelfodilihaddaden/Desktop/gitlab/mini007/R/main.R#259: tasks <- unlist(strsplit(result, "\n"))
#> debug at /Users/mohamedelfodilihaddaden/Desktop/gitlab/mini007/R/main.R#260: tasks <- trimws(tasks)
#> debug at /Users/mohamedelfodilihaddaden/Desktop/gitlab/mini007/R/main.R#261: tasks <- tasks[tasks != ""]
#> debug at /Users/mohamedelfodilihaddaden/Desktop/gitlab/mini007/R/main.R#263: if (!length(tasks) == 3) {
#>     stop("tasks tooo many")
#> }
#> debug at /Users/mohamedelfodilihaddaden/Desktop/gitlab/mini007/R/main.R#266: return(tasks)
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> [1] "0edd2e06-a9a2-4f40-818a-9529938b0643"
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$prompt
#> [1] "Gather up-to-date information on Algeria's economic situation, including key indicators such as GDP growth, main industries, unemployment rate, inflation, and recent economic challenges or reforms."
#> 
#> [[1]]$response
#> [1] "Research the latest data on Algeria's GDP growth rate from reliable economic sources.\nCollect information on Algeria's main industries, such as hydrocarbons, agriculture, and manufacturing.\nFind current statistics on Algeria's unemployment rate and inflation.\nIdentify recent economic challenges Algeria is facing, including budget deficits or external debt.\nLook for recent economic reforms or government initiatives aimed at improving the economy."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "3d5e2527-ed63-4c44-9e96-4c54dc8ae930"
#> 
#> [[2]]$agent_name
#> [1] "summarizer"
#> 
#> [[2]]$prompt
#> [1] "Identify the three most important points that succinctly describe the current economic status of Algeria."
#> 
#> [[2]]$response
#> [1] "Identify the three key aspects of Algeria's economy: reliance on hydrocarbons and its impact on GDP growth.\nHighlight the unemployment rate and inflation as major economic challenges.\nSummarize recent economic reforms and initiatives aimed at diversification and fiscal stability."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> [1] "c3ffa3c5-368a-4a72-87e0-913d59abc315"
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$prompt
#> [1] "Translate the three bullet points accurately into German."
#> 
#> [[3]]$response
#> [1] "Identifizieren Sie die drei wichtigsten Aspekte der algerischen Wirtschaft: die Abhängigkeit von Erdöl und Erdgas und deren Auswirkungen auf das BIP-Wachstum.  \nHeben Sie die Arbeitslosenquote und die Inflation als große wirtschaftliche Herausforderungen hervor.  \nFassen Sie die jüngsten Wirtschaftsreformen und Initiativen zur Diversifizierung und fiskalischen Stabilität zusammen."
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
