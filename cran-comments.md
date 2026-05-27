── R CMD check results ──────────── mini007 0.3.0 ────
Duration: 9.8s

❯ checking for future file timestamps ... NOTE
  unable to verify current time

0 errors ✔ | 0 warnings ✔ | 1 note ✖

- Implementing the `Workflow` class which allows one to have full control over a `workflow` of agents
- Adding new methods: `share_context_with()`

── R CMD check results ────────────── mini007 0.2.2 ────
Duration: 9.3s

0 errors ✔ | 0 warnings ✔ | 0 notes ✔
### Comments: 

# mini007 0.3.0
#### Adding new methods to work with `tools`: 
- `register_tools()`
- `list_tools()`
- `remove_tools()`
- `clear_tools()`
- `generate_and_register_tool()` 

#### Adding the `agents_dialog()` methods that allows 2 agents to interact with each other in order to come up with a better outcome. 
