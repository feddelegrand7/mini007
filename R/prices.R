# Custom model prices. ellmer computes costs from its own price table, which
# lags behind new model releases: for an unknown model `get_cost()` returns
# NA. Prices registered here are used instead of ellmer's for the matching
# models, by every agent in the session.

.prices <- new.env(parent = emptyenv())

empty_prices <- function() {
  data.frame(
    provider = character(),
    model = character(),
    input = numeric(),
    output = numeric(),
    cached_input = numeric(),
    stringsAsFactors = FALSE
  )
}

.prices$table <- empty_prices()

#' Set the price of a model
#'
#' @description
#' Registers the price of one or more models, in US dollars per million
#' tokens. Agents use these prices to compute their cost (`$cost`,
#' `$get_usage_stats()`) and to enforce their budget.
#'
#' ellmer only knows the prices of the models in its built-in table, and
#' returns a cost of `NA` for any other model (for instance a model released
#' after your ellmer version). Use `set_prices()` to fill in these models, or
#' to override a price that is out of date: prices set here take precedence
#' over ellmer's.
#'
#' Prices are kept for the R session and apply to every agent, including
#' agents created before the price was set.
#'
#' @param model `[character]` Model name(s), as given to ellmer (eg.
#'   `"gpt-5.6"`). For `clear_prices()`: the model(s) whose prices to remove,
#'   or `NULL` (default) to remove all prices.
#' @param input `[numeric]` Price in USD per million input tokens.
#' @param output `[numeric]` Price in USD per million output tokens.
#' @param cached_input `[numeric]` Price in USD per million cached input
#'   tokens. When `NA` (default), cached tokens are charged at the `input`
#'   price.
#' @param provider `[character | NULL]` Provider name(s) as reported by
#'   ellmer (eg. `"OpenAI"`, matched case-insensitively). `NULL` (default)
#'   matches the model whatever the provider. A price set for a specific
#'   provider takes precedence over one set for any provider. For
#'   `clear_prices()`: only remove the prices set for these providers.
#'
#' All arguments are recycled to the length of `model`. Setting the price of
#' a model that already has one replaces it.
#'
#' @return `set_prices()` and `clear_prices()` invisibly return, and
#'   `get_prices()` returns, the table of registered prices: a data frame
#'   with columns `provider`, `model`, `input`, `output` and `cached_input`.
#' @examples
#' set_prices("gpt-5.6", input = 1.25, output = 10)
#' set_prices(
#'   c("my-model-small", "my-model-large"),
#'   input = c(0.1, 1), output = c(0.4, 4), provider = "OpenAI"
#' )
#' get_prices()
#' clear_prices("my-model-small")
#' clear_prices()
#' @export
set_prices <- function(model, input, output, cached_input = NA, provider = NULL) {
  checkmate::assert_character(model, min.len = 1, any.missing = FALSE, min.chars = 1)
  n <- length(model)
  checkmate::assert_numeric(input, lower = 0, any.missing = FALSE, finite = TRUE, min.len = 1)
  checkmate::assert_numeric(output, lower = 0, any.missing = FALSE, finite = TRUE, min.len = 1)
  checkmate::assert_numeric(cached_input, lower = 0, finite = TRUE, min.len = 1)
  checkmate::assert_character(provider, any.missing = FALSE, min.chars = 1, min.len = 1, null.ok = TRUE)
  for (x in list(input, output, cached_input, provider)) {
    if (!is.null(x) && !length(x) %in% c(1L, n)) {
      cli::cli_abort("Price arguments must have length 1 or the length of {.arg model} ({n}).")
    }
  }

  new <- data.frame(
    provider = rep_len(if (is.null(provider)) NA_character_ else provider, n),
    model = model,
    input = rep_len(as.numeric(input), n),
    output = rep_len(as.numeric(output), n),
    cached_input = rep_len(as.numeric(cached_input), n),
    stringsAsFactors = FALSE
  )
  # Within one call, the last price given for a model wins.
  new <- new[!duplicated(price_key(new), fromLast = TRUE), , drop = FALSE]

  # A model that already has a price keeps its place in the table.
  table <- .prices$table
  pos <- match(price_key(new), price_key(table))
  table[pos[!is.na(pos)], ] <- new[!is.na(pos), , drop = FALSE]
  table <- rbind(table, new[is.na(pos), , drop = FALSE])
  rownames(table) <- NULL
  .prices$table <- table

  invisible(get_prices())
}

#' @rdname set_prices
#' @export
get_prices <- function() {
  .prices$table
}

#' @rdname set_prices
#' @export
clear_prices <- function(model = NULL, provider = NULL) {
  checkmate::assert_character(model, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_character(provider, any.missing = FALSE, null.ok = TRUE)
  table <- .prices$table
  drop <- if (is.null(model)) rep(TRUE, nrow(table)) else table$model %in% model
  if (!is.null(provider)) drop <- drop & tolower(table$provider) %in% tolower(provider)
  .prices$table <- table[!drop, , drop = FALSE]
  rownames(.prices$table) <- NULL
  invisible(get_prices())
}

price_key <- function(table) {
  paste(tolower(ifelse(is.na(table$provider), "", table$provider)), table$model, sep = "\r")
}

# The registered price of a model: the row for this exact provider if any,
# else the row that matches any provider, else NULL.
lookup_price <- function(provider, model) {
  table <- .prices$table
  if (!nrow(table) || !is_string(model)) return(NULL)
  rows <- table[table$model == model, , drop = FALSE]
  if (!nrow(rows)) return(NULL)
  exact <- if (is_string(provider)) which(tolower(rows$provider) == tolower(provider)) else integer()
  any_provider <- which(is.na(rows$provider))
  pick <- c(exact, any_provider)
  if (!length(pick)) return(NULL)
  as.list(rows[pick[[1L]], , drop = FALSE])
}

is_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

# Cost in USD of one turn's tokens, c(input, output, cached_input), where
# `input` excludes the cached tokens (ellmer's convention).
tokens_cost <- function(tokens, price) {
  tokens <- as.numeric(tokens)
  tokens <- c(tokens, rep(0, 3L))[1:3]
  cached_price <- if (is.na(price$cached_input)) price$input else price$cached_input
  sum(tokens * c(price$input, price$output, cached_price)) / 1e6
}

#' Cost of an ellmer chat
#'
#' @description
#' The cost in US dollars of the conversation held by an ellmer chat object,
#' as used by agents. When a price was registered for the chat's model with
#' [set_prices()], the cost is computed from the token usage of each
#' assistant turn with that price. Otherwise it is ellmer's own estimate
#' (`llm_object$get_cost()`), which is `NA` for models ellmer has no price
#' for.
#'
#' @param llm_object An ellmer chat object (eg. an agent's `$llm_object`).
#' @param include `"all"` (default) for the whole conversation, or `"last"`
#'   for the last assistant turn only.
#' @return A number: the cost in USD, or `NA` if it is unknown.
#' @examples
#' \dontrun{
#' chat <- ellmer::chat("openai/gpt-5.6", echo = "none")
#' chat$chat("Hello")
#' llm_cost(chat) # NA: ellmer has no price for this model
#' set_prices("gpt-5.6", input = 1.25, output = 10)
#' llm_cost(chat)
#' }
#' @export
llm_cost <- function(llm_object, include = c("all", "last")) {
  include <- match.arg(include)
  provider <- tryCatch(llm_object$get_provider(), error = function(e) NULL)
  price <- if (!is.null(provider)) {
    tryCatch(lookup_price(provider@name, provider@model), error = function(e) NULL)
  }

  if (is.null(price)) {
    cost <- tryCatch(
      if (include == "all") llm_object$get_cost() else llm_object$get_cost(include = "last"),
      error = function(e) NA_real_
    )
    cost <- suppressWarnings(as.numeric(unclass(cost)))
    return(if (length(cost)) cost[[1L]] else NA_real_)
  }

  turns <- llm_object$get_turns()
  assistant <- Filter(function(turn) identical(turn@role, "assistant"), turns)
  if (!length(assistant)) return(0)
  if (include == "last") assistant <- assistant[length(assistant)]
  sum(vapply(assistant, function(turn) tokens_cost(turn@tokens, price), numeric(1L)))
}
