
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

🌐 Compatible with any OpenAI-style chat model via `ellmer`.

You can install the development version of `mini007` like so:

``` r
devtools::install_github("feddelegrand7/mini007")
```

### Creating an Agent

Creating an agent is really easy, you need to provide the `OpenAI` API
key and the `model` name. Note that at the moment, only `OpenAI` models
are supported but if needed, feel free to open an issue:

``` r
library(mini007)
```

``` r
polar_bear_researcher <- Agent$new(
  name = "POLAR BEAR RESEARCHER",
  instruction = "You are an expert in polar bears, you task is to collect information about polar bears.",
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)
```

Each created Agent has an `agent_id`, a `name` and an `instruction`.

``` r
polar_bear_researcher$agent_id
#> [1] "fe8c2fc1-a99a-4e7e-8f24-51aab47ca9b4"
```

``` r
polar_bear_researcher$name
#> [1] "POLAR BEAR RESEARCHER"
```

``` r
polar_bear_researcher$instruction
#> [1] "You are an expert in polar bears, you task is to collect information about polar bears."
```

As mentioned previously, in a technical term, an Agent is an extension
of an `ellmer` object. You can execute the following in order to access
the underlying `ellmer` object:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=1 tokens=0/0 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
```

You can tweak the `llm_object` the same way as an `ellmer` object (set a
structured output, define a set of tools and so on).

An agent can provide the answer to a prompt using the `invoke` method:

``` r
polar_bear_researcher$invoke("Are polar bears dangerous for humans?")
#> [1] "Yes, polar bears can be dangerous to humans. They are large, powerful predators adapted to the Arctic environment, and they are capable of attacking if they feel threatened, are surprised, or if they are hungry. Although polar bear attacks on humans are relatively rare compared to other wildlife encounters, they are considered one of the most dangerous bear species because of their size, strength, and predatory nature.\n\nKey points about the danger polar bears pose to humans:\n- Polar bears are apex predators and primarily hunt seals for food, but they may see humans as potential prey, especially in areas where their natural food sources are scarce.\n- They have been known to attack humans both defensively and opportunistically.\n- Polar bears are generally solitary animals, so an encounter can be unpredictable and potentially hazardous.\n- People living or traveling in polar bear habitats are advised to take precautions, including carrying deterrents such as bear spray, making noise to avoid surprising bears, and storing food securely.\n\nIn summary, while polar bears do not normally seek out humans as prey, they are dangerous animals that require caution and respect in the wild."
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
#> [1] "Yes, polar bears can be dangerous to humans. They are large, powerful predators adapted to the Arctic environment, and they are capable of attacking if they feel threatened, are surprised, or if they are hungry. Although polar bear attacks on humans are relatively rare compared to other wildlife encounters, they are considered one of the most dangerous bear species because of their size, strength, and predatory nature.\n\nKey points about the danger polar bears pose to humans:\n- Polar bears are apex predators and primarily hunt seals for food, but they may see humans as potential prey, especially in areas where their natural food sources are scarce.\n- They have been known to attack humans both defensively and opportunistically.\n- Polar bears are generally solitary animals, so an encounter can be unpredictable and potentially hazardous.\n- People living or traveling in polar bear habitats are advised to take precautions, including carrying deterrents such as bear spray, making noise to avoid surprising bears, and storing food securely.\n\nIn summary, while polar bears do not normally seek out humans as prey, they are dangerous animals that require caution and respect in the wild."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/220 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [220] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous to humans. They are large, powerful predators adapted to the Arctic environment, and they are capable of attacking if they feel threatened, are surprised, or if they are hungry. Although polar bear attacks on humans are relatively rare compared to other wildlife encounters, they are considered one of the most dangerous bear species because of their size, strength, and predatory nature.
#> 
#> Key points about the danger polar bears pose to humans:
#> - Polar bears are apex predators and primarily hunt seals for food, but they may see humans as potential prey, especially in areas where their natural food sources are scarce.
#> - They have been known to attack humans both defensively and opportunistically.
#> - Polar bears are generally solitary animals, so an encounter can be unpredictable and potentially hazardous.
#> - People living or traveling in polar bear habitats are advised to take precautions, including carrying deterrents such as bear spray, making noise to avoid surprising bears, and storing food securely.
#> 
#> In summary, while polar bears do not normally seek out humans as prey, they are dangerous animals that require caution and respect in the wild.
```

### Creating a multi-agents orchestraction

We can create as many Agents as we want, the `LeadAgent` will dispatch
the instructions to the agents and provide with the final answer back.
Let’s create two other Agents, a `summarizer` and a `translator`:

``` r

researcher <- Agent$new(
  name = "researcher",
  instruction = "You are a research assistant. Your job is to answer factual questions with detailed and accurate information. Do not answer with more than 2 lines",
  model = "gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY")
)

summarizer <- Agent$new(
  name = "summarizer",
  instruction = "You are a French translator. Only translate the input text into natural French without changing meaning.",
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)

translator <- Agent$new(
  name = "translator",
  instruction = "Your role is to translate a text from English to German",
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)
```

Now, the most important part is to create a `LeadAgent`:

``` r
lead_agent <- LeadAgent$new(
  name = "Leader", 
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)
```

Note that the `LeadAgent` cannot receive an `instruction` as it has
already the necessary instructions.

Next, we need to assign the Agents to `LeadAgent`, we do it as follows:

``` r
lead_agent$register_agents(c(researcher, summarizer, translator))
lead_agent$agents
#> $`8636deeb-cf52-48ee-b8cc-7a0ab1620169`
#> <Agent>
#>   Public:
#>     agent_id: 8636deeb-cf52-48ee-b8cc-7a0ab1620169
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = TRUE, api_key = NULL) 
#>     instruction: You are a research assistant. Your job is to answer fact ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     name: researcher
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> $`df5b934e-cc2a-4a48-b8e0-b57a079f781a`
#> <Agent>
#>   Public:
#>     agent_id: df5b934e-cc2a-4a48-b8e0-b57a079f781a
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = TRUE, api_key = NULL) 
#>     instruction: You are a French translator. Only translate the input te ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     name: summarizer
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> $`5680729f-829e-4613-b0a5-965de4a5c1d7`
#> <Agent>
#>   Public:
#>     agent_id: 5680729f-829e-4613-b0a5-965de4a5c1d7
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = TRUE, api_key = NULL) 
#>     instruction: Your role is to translate a text from English to German
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     name: translator
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user")
```

You can see from above that the above defined Agents are now assigned to
the `LeadAgent`.

In order now to execute the workflow, we just need to call the `invoke`
method which will behind the scene delegate the prompts to suitable
Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
```

``` r
response
#> [1] "- Die Wirtschaft Algeriens wächst moderat mit einem BIP-Wachstum von 2-3 % bei einer Inflation von etwa 6 %.  \n- Die wichtigsten Sektoren, die die Wirtschaft antreiben, sind Kohlenwasserstoffe (Öl und Gas), Landwirtschaft und verarbeitendes Gewerbe.  \n- Die Arbeitslosigkeit bleibt eine Herausforderung, insbesondere unter Jugendlichen, mit etwa 12-15 %."
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> [1] "8636deeb-cf52-48ee-b8cc-7a0ab1620169"
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$prompt
#> [1] "1. Research the current economic situation in Algeria, including key indicators such as GDP growth, inflation rate, major industries, and employment statistics."
#> 
#> [[1]]$response
#> [1] "As of early 2024, Algeria's GDP growth is modest at around 2-3%, inflation hovers near 6%, major industries include hydrocarbons (oil and gas), agriculture, and manufacturing, while unemployment remains high at approximately 12-15%, particularly among youth."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "8636deeb-cf52-48ee-b8cc-7a0ab1620169"
#> 
#> [[2]]$agent_name
#> [1] "researcher"
#> 
#> [[2]]$prompt
#> [1] "2. Summarize the gathered information into 3 concise bullet points highlighting the main aspects of Algeria's economy."
#> 
#> [[2]]$response
#> [1] "- Algeria's economy is growing modestly at 2-3% GDP growth with inflation around 6%.  \n- The key sectors driving the economy are hydrocarbons (oil and gas), agriculture, and manufacturing.  \n- Unemployment remains a challenge, particularly among youth, at approximately 12-15%."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> [1] "5680729f-829e-4613-b0a5-965de4a5c1d7"
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$prompt
#> [1] "3. Translate the 3 bullet points from English into German accurately, maintaining the meaning and context."
#> 
#> [[3]]$response
#> [1] "- Die Wirtschaft Algeriens wächst moderat mit einem BIP-Wachstum von 2-3 % bei einer Inflation von etwa 6 %.  \n- Die wichtigsten Sektoren, die die Wirtschaft antreiben, sind Kohlenwasserstoffe (Öl und Gas), Landwirtschaft und verarbeitendes Gewerbe.  \n- Die Arbeitslosigkeit bleibt eine Herausforderung, insbesondere unter Jugendlichen, mit etwa 12-15 %."
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
