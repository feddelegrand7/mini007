# mini007 0.2.0

- Setting `messages` as an `active` `R6` field. It is now possible to modify the `messages` that will be used by the `LLM` object through a `list` object. The `list` object will be automatically convert to the corresponding `ellmer` `Turns`. 

Adding the following new methods: 
- `truncate_history()`
- `update_instruction()`
- `clear_and_summarise_messages()`
- `judge_and_chose_best_response()`


# mini007 0.1.0

* Initial CRAN submission.
