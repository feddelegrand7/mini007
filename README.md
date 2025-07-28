
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
#> [1] "765e0360-51ac-42b1-8537-86c406193936"
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
#> [1] "Yes, polar bears can be dangerous to humans. They are large, powerful predators and are considered one of the most dangerous bears due to their size, strength, and hunting capabilities. Polar bears primarily hunt seals and live in the Arctic region, where human encounters are relatively rare but can be risky.\n\nPolar bears may become aggressive if they feel threatened, are surprised, or are protecting their cubs. In some cases, polar bears have attacked humans, particularly when food is scarce or when bears become habituated to human presence.\n\nIf you are in polar bear territory, it is important to take precautions, such as carrying deterrents like bear spray, making noise to avoid surprising bears, and storing food securely to prevent attracting them. It’s also advised to travel in groups and follow local guidelines to minimize the risk of dangerous encounters."
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
#> [1] "Yes, polar bears can be dangerous to humans. They are large, powerful predators and are considered one of the most dangerous bears due to their size, strength, and hunting capabilities. Polar bears primarily hunt seals and live in the Arctic region, where human encounters are relatively rare but can be risky.\n\nPolar bears may become aggressive if they feel threatened, are surprised, or are protecting their cubs. In some cases, polar bears have attacked humans, particularly when food is scarce or when bears become habituated to human presence.\n\nIf you are in polar bear territory, it is important to take precautions, such as carrying deterrents like bear spray, making noise to avoid surprising bears, and storing food securely to prevent attracting them. It’s also advised to travel in groups and follow local guidelines to minimize the risk of dangerous encounters."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/164 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [164] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous to humans. They are large, powerful predators and are considered one of the most dangerous bears due to their size, strength, and hunting capabilities. Polar bears primarily hunt seals and live in the Arctic region, where human encounters are relatively rare but can be risky.
#> 
#> Polar bears may become aggressive if they feel threatened, are surprised, or are protecting their cubs. In some cases, polar bears have attacked humans, particularly when food is scarce or when bears become habituated to human presence.
#> 
#> If you are in polar bear territory, it is important to take precautions, such as carrying deterrents like bear spray, making noise to avoid surprising bears, and storing food securely to prevent attracting them. It’s also advised to travel in groups and follow local guidelines to minimize the risk of dangerous encounters.
```

### Creating a multi-agents orchestraction

We can create as many Agents as we want, the `LeadAgent` will dispatch
the instructions to the agents and provide with the final answer back.
Let’s create three Agents, a `researcher`, a `summarizer` and a
`translator`:

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
```

Now, the most important part is to create a `LeadAgent`:

``` r
lead_agent <- LeadAgent$new(
  name = "Leader", 
  llm_object = openai_llm_object
)
```

Note that the `LeadAgent` cannot receive an `instruction` as it has
already the necessary instructions.

Next, we need to assign the Agents to `LeadAgent`, we do it as follows:

``` r
lead_agent$register_agents(c(researcher, summarizer, translator))
lead_agent$agents
#> $`b474a5e8-d600-4256-aa4e-509777bbada8`
#> <Agent>
#>   Public:
#>     agent_id: b474a5e8-d600-4256-aa4e-509777bbada8
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: You are a research assistant. Your job is to answer fact ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: researcher
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> $`6067c0f9-3c8a-4245-98d1-8a2fc8511fdc`
#> <Agent>
#>   Public:
#>     agent_id: 6067c0f9-3c8a-4245-98d1-8a2fc8511fdc
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: You are agent designed to summarise a give text into 3 d ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: summarizer
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> $`0162f54b-d99d-4c75-8407-d674cbfc6237`
#> <Agent>
#>   Public:
#>     agent_id: 0162f54b-d99d-4c75-8407-d674cbfc6237
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: Your role is to translate a text from English to German
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: translator
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user")
```

In order now to execute the workflow, we just need to call the `invoke`
method which will behind the scene delegate the prompts to suitable
Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
```

``` r
response
#> [1] "- Die algerische Wirtschaft ist stark von Kohlenwasserstoffen abhängig, die etwa 95 % der Exporte und 30 % des BIP ausmachen.  \n- Es werden Anstrengungen unternommen, die Wirtschaft zu diversifizieren, mit langsamem Wachstum im Landwirtschafts- und Industriesektor.  \n- Die Inflation liegt moderat bei 6-7 %, während die Arbeitslosigkeit mit etwa 12-14 % hoch bleibt."
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> [1] "b474a5e8-d600-4256-aa4e-509777bbada8"
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[1]]$model_provider
#> [1] "OpenAI"
#> 
#> [[1]]$prompt
#> [1] "Gather current information about the economic situation in Algeria, including key statistics and trends."
#> 
#> [[1]]$response
#> [1] "As of mid-2024, Algeria's economy is marked by dependence on hydrocarbons, contributing about 95% of exports and 30% of GDP; oil prices and output cuts impact revenue. The government is focusing on diversification, with sectors like agriculture and manufacturing growing slowly; inflation is moderate around 6-7%, and unemployment remains high near 12-14%."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "6067c0f9-3c8a-4245-98d1-8a2fc8511fdc"
#> 
#> [[2]]$agent_name
#> [1] "summarizer"
#> 
#> [[2]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[2]]$model_provider
#> [1] "OpenAI"
#> 
#> [[2]]$prompt
#> [1] "Summarize the economic situation in Algeria in three concise bullet points."
#> 
#> [[2]]$response
#> [1] "- Algeria's economy heavily relies on hydrocarbons, which make up around 95% of exports and 30% of GDP.  \n- Efforts to diversify the economy are underway, with slow growth in agriculture and manufacturing sectors.  \n- Inflation is moderate at 6-7%, while unemployment remains high at approximately 12-14%."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> [1] "0162f54b-d99d-4c75-8407-d674cbfc6237"
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[3]]$model_provider
#> [1] "OpenAI"
#> 
#> [[3]]$prompt
#> [1] "Translate the three bullet points about Algeria's economic situation into German."
#> 
#> [[3]]$response
#> [1] "- Die algerische Wirtschaft ist stark von Kohlenwasserstoffen abhängig, die etwa 95 % der Exporte und 30 % des BIP ausmachen.  \n- Es werden Anstrengungen unternommen, die Wirtschaft zu diversifizieren, mit langsamem Wachstum im Landwirtschafts- und Industriesektor.  \n- Die Inflation liegt moderat bei 6-7 %, während die Arbeitslosigkeit mit etwa 12-14 % hoch bleibt."
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
