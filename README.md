
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
#> [1] "8553923e-cd97-4b2b-852f-839379ff93c6"
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
#> [1] "Yes, polar bears can be dangerous to humans. They are the largest land carnivores and are powerful predators. While polar bears generally avoid human contact, they may become aggressive if they feel threatened, are surprised, or are hungry. Attacks on humans, though relatively rare, have occurred, especially in areas where bears and people come into close proximity, such as Arctic communities or during expeditions.\n\nKey points about polar bears and human danger:\n\n- Polar bears are strong and capable hunters, able to kill large prey like seals.\n- They have been known to attack humans, particularly when food is scarce or they're protecting their cubs.\n- Most attacks occur because bears are surprised, feel threatened, or are habituated to human presence.\n- In Arctic regions, communities have measures in place to avoid and manage polar bear encounters, such as bear patrols and use of deterrents.\n- Travelers and researchers in polar bear habitats are advised to carry deterrents (e.g., bear spray, firearms in some cases) and follow safety protocols.\n\nIn summary, while polar bears do not typically seek out humans as prey, they pose a significant risk due to their size and predatory nature, and caution is essential when in bear country."
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
#> [1] "Yes, polar bears can be dangerous to humans. They are the largest land carnivores and are powerful predators. While polar bears generally avoid human contact, they may become aggressive if they feel threatened, are surprised, or are hungry. Attacks on humans, though relatively rare, have occurred, especially in areas where bears and people come into close proximity, such as Arctic communities or during expeditions.\n\nKey points about polar bears and human danger:\n\n- Polar bears are strong and capable hunters, able to kill large prey like seals.\n- They have been known to attack humans, particularly when food is scarce or they're protecting their cubs.\n- Most attacks occur because bears are surprised, feel threatened, or are habituated to human presence.\n- In Arctic regions, communities have measures in place to avoid and manage polar bear encounters, such as bear patrols and use of deterrents.\n- Travelers and researchers in polar bear habitats are advised to carry deterrents (e.g., bear spray, firearms in some cases) and follow safety protocols.\n\nIn summary, while polar bears do not typically seek out humans as prey, they pose a significant risk due to their size and predatory nature, and caution is essential when in bear country."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/245 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [245] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous to humans. They are the largest land carnivores and are powerful predators. While polar bears generally avoid human contact, they may become aggressive if they feel threatened, are surprised, or are hungry. Attacks on humans, though relatively rare, have occurred, especially in areas where bears and people come into close proximity, such as Arctic communities or during expeditions.
#> 
#> Key points about polar bears and human danger:
#> 
#> - Polar bears are strong and capable hunters, able to kill large prey like seals.
#> - They have been known to attack humans, particularly when food is scarce or they're protecting their cubs.
#> - Most attacks occur because bears are surprised, feel threatened, or are habituated to human presence.
#> - In Arctic regions, communities have measures in place to avoid and manage polar bear encounters, such as bear patrols and use of deterrents.
#> - Travelers and researchers in polar bear habitats are advised to carry deterrents (e.g., bear spray, firearms in some cases) and follow safety protocols.
#> 
#> In summary, while polar bears do not typically seek out humans as prey, they pose a significant risk due to their size and predatory nature, and caution is essential when in bear country.
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
#> $`3f4cfc05-5839-48e8-9294-b13119480819`
#> <Agent>
#>   Public:
#>     agent_id: 3f4cfc05-5839-48e8-9294-b13119480819
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
#> $`37dd5724-6d93-48f7-a99f-3c017ce98c3b`
#> <Agent>
#>   Public:
#>     agent_id: 37dd5724-6d93-48f7-a99f-3c017ce98c3b
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
#> $`3d57f850-b179-4f25-8db0-f859ca31f362`
#> <Agent>
#>   Public:
#>     agent_id: 3d57f850-b179-4f25-8db0-f859ca31f362
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
#> [1] "- Das BIP-Wachstum Algeriens ist moderat bei 2-3 %, hauptsächlich angetrieben durch den Bereich der Kohlenwasserstoffe, der etwa 30 % der Wirtschaft ausmacht.  \n- Wichtige Branchen, die die Wirtschaft antreiben, sind Energie, Bergbau, Landwirtschaft und verarbeitendes Gewerbe.  \n- Zu den großen Herausforderungen zählen die starke Abhängigkeit von Ölexporten, hohe Arbeitslosenraten und der dringende Bedarf an wirtschaftlicher Diversifikation."
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> [1] "3f4cfc05-5839-48e8-9294-b13119480819"
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
#> [1] "Gather recent data on Algeria's economic situation, including GDP growth, main industries, and challenges."
#> 
#> [[1]]$response
#> [1] "As of 2023-2024, Algeria's GDP growth is estimated around 2-3%, driven mainly by hydrocarbons (oil and gas) accounting for ~30% of GDP; main industries include energy, mining, agriculture, and manufacturing. Challenges include reliance on oil exports, high unemployment, and need for economic diversification amid fluctuating oil prices."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "37dd5724-6d93-48f7-a99f-3c017ce98c3b"
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
#> [1] "Summarize the economic situation of Algeria into 3 concise bullet points in English."
#> 
#> [[2]]$response
#> [1] "- Algeria's GDP growth is moderate at 2-3%, primarily fueled by its hydrocarbons sector, which represents about 30% of the economy.  \n- Key industries driving the economy include energy, mining, agriculture, and manufacturing.  \n- Major challenges consist of heavy dependence on oil exports, high unemployment rates, and the urgent need for economic diversification."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> [1] "3d57f850-b179-4f25-8db0-f859ca31f362"
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
#> [1] "Translate the 3 bullet points summary into German."
#> 
#> [[3]]$response
#> [1] "- Das BIP-Wachstum Algeriens ist moderat bei 2-3 %, hauptsächlich angetrieben durch den Bereich der Kohlenwasserstoffe, der etwa 30 % der Wirtschaft ausmacht.  \n- Wichtige Branchen, die die Wirtschaft antreiben, sind Energie, Bergbau, Landwirtschaft und verarbeitendes Gewerbe.  \n- Zu den großen Herausforderungen zählen die starke Abhängigkeit von Ölexporten, hohe Arbeitslosenraten und der dringende Bedarf an wirtschaftlicher Diversifikation."
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
