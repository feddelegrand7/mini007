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
- `generate_r_code()`


# mini007 0.1.0

* Initial CRAN submission.
