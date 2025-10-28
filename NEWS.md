# mini007 0.2.0

- Setting `messages` as an `active` `R6` field. It is now possible to modify the `messages` that will be used by the `LLM` object through a `list` object. The `list` object will be automatically converted to the corresponding `ellmer` `Turns`. 

Adding the following new methods: 
- `keep_last_n_messages()`
- `update_instruction()`
- `clear_and_summarise_messages()`
- `judge_and_choose_best_response()`
- `set_budget()`
- `export_messages_history()` and `load_messages_history()`
- `reset_conversation_history()`
- `add_message()`
- `generate_execute_r_code()`
- `visualize_plan()`
- `set_budget_policy()`

Adding the following new parameters: 
- Adding the `force_regenerate_plan` boolean parameter to the `invoke` method of the `LeadAgent`, this will allow taking into account if the `LeadAgent` has already generated a plan or not. If a plan is detected, no need to generate the plan from scratch, except if the user set the `force_generate_plan` to `TRUE`.

Deleting the following method:
- `delegate_prompt()`, not needed anymore as the `generate_plan()` method has the same behavior. 

# mini007 0.1.0

* Initial CRAN submission.
