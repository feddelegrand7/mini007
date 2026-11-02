#' Memory: Lessons and Outcomes Agents Learn From
#'
#' @description
#' A `Memory` stores what agents learned from past tasks so that later tasks
#' can benefit from it, within a session or across sessions when a `path` is
#' given. It holds two kinds of records:
#'
#' * **Lessons**: short, reusable strategy notes distilled by an LLM from a
#'   judged task ("for X, doing Y worked" / "avoid Z"). Relevant lessons are
#'   retrieved and added to the prompt of future tasks.
#' * **Outcomes**: one record per judged task (agent, task, success, score).
#'   They form each agent's track record, which a `LeadAgent` uses when
#'   choosing which agent should handle a task.
#'
#' Attach a memory with \code{$set_memory()} on an `Agent` or a `LeadAgent`.
#' Several agents can share the same `Memory` object.
#'
#' Retrieval ranks lessons by keyword relevance (BM25) to the task at hand,
#' with no extra dependency. Supply `search_fn` to plug in another retriever,
#' e.g. one based on embeddings.
#'
#' @examples
#' memory <- Memory$new()
#' memory$add_lesson(
#'   lesson = "When translating to German, keep product names in English.",
#'   task = "Translate the product description to German",
#'   agent_name = "translator",
#'   score = 0.9,
#'   success = TRUE
#' )
#' memory$search("Translate this text to German")
#'
#' # Persist across sessions
#' path <- tempfile(fileext = ".json")
#' memory <- Memory$new(path = path)
#'
#' @importFrom jsonlite read_json write_json
#' @export
Memory <- R6::R6Class(
  classname = "Memory",

  public = list(

    #' @field path `[character(1) | NULL]` JSON file the memory is saved to
    #'   after every change. `NULL` keeps the memory in the current session only.
    path = NULL,
    #' @field lessons A list of lesson records (`id`, `lesson`, `task`,
    #'   `agent_name`, `score`, `success`, `created_at`).
    lessons = list(),
    #' @field outcomes A list of outcome records (`agent_name`, `task`,
    #'   `success`, `score`, `source`, `created_at`).
    outcomes = list(),
    #' @field max_lessons Maximum number of lessons kept (oldest are dropped first).
    max_lessons = NULL,
    #' @field max_outcomes Maximum number of outcomes kept (oldest are dropped first).
    max_outcomes = NULL,

    #' @description
    #' Create a memory, loading it from `path` when that file exists.
    #' @param path `[character(1) | NULL]` JSON file to persist the memory
    #'   to. Defaults to `NULL` (in-session only).
    #' @param max_lessons `[integerish(1)]` Maximum number of lessons kept. Default 500.
    #' @param max_outcomes `[integerish(1)]` Maximum number of outcomes kept. Default 1000.
    #' @param search_fn `[function | NULL]` Optional custom retriever with
    #'   signature `function(query, lessons, k)` returning a list of at most
    #'   `k` lessons taken from `lessons`, most relevant first.
    initialize = function(path = NULL, max_lessons = 500, max_outcomes = 1000,
                          search_fn = NULL) {
      checkmate::assert_string(path, null.ok = TRUE)
      checkmate::assert_int(max_lessons, lower = 1)
      checkmate::assert_int(max_outcomes, lower = 1)
      checkmate::assert_function(search_fn, null.ok = TRUE)

      self$path <- path
      self$max_lessons <- as.integer(max_lessons)
      self$max_outcomes <- as.integer(max_outcomes)
      private$.search_fn <- search_fn

      if (!is.null(path) && file.exists(path)) {
        self$load(path)
      }
    },

    #' @description
    #' Store a lesson.
    #' @param lesson `[character(1)]` The lesson text.
    #' @param task `[character(1)]` The task the lesson was learned from.
    #' @param agent_name `[character(1)]` Name of the agent that performed the task.
    #' @param score `[numeric(1)]` Judge score of the task (0 to 1), `NA` if unknown.
    #' @param success `[logical(1)]` Whether the task succeeded, `NA` if unknown.
    #' @return Invisibly, the stored lesson record.
    add_lesson = function(lesson, task = NA_character_, agent_name = NA_character_,
                          score = NA_real_, success = NA) {
      checkmate::assert_string(lesson, min.chars = 1)
      checkmate::assert_string(task, na.ok = TRUE)
      checkmate::assert_string(agent_name, na.ok = TRUE)
      checkmate::assert_number(score, na.ok = TRUE)
      checkmate::assert_flag(success, na.ok = TRUE)

      record <- list(
        id         = uuid::UUIDgenerate(),
        lesson     = trimws(lesson),
        task       = task,
        agent_name = agent_name,
        score      = score,
        success    = success,
        created_at = private$.now()
      )

      self$lessons[[length(self$lessons) + 1L]] <- record
      self$lessons <- keep_last(self$lessons, self$max_lessons)
      private$.persist()

      invisible(record)
    },

    #' @description
    #' Record the outcome of a task.
    #' @param agent_name `[character(1)]` Name of the agent that performed the task.
    #' @param task `[character(1)]` The task.
    #' @param success `[logical(1)]` Whether the task succeeded.
    #' @param score `[numeric(1)]` Judge score (0 to 1), `NA` if unknown.
    #' @param source `[character(1)]` Where the verdict comes from, e.g.
    #'   `"validation"` or `"hitl"`.
    #' @return Invisibly, the stored outcome record.
    add_outcome = function(agent_name, task, success, score = NA_real_,
                           source = "validation") {
      checkmate::assert_string(agent_name)
      checkmate::assert_string(task)
      checkmate::assert_flag(success)
      checkmate::assert_number(score, na.ok = TRUE)
      checkmate::assert_string(source)

      record <- list(
        agent_name = agent_name,
        task       = task,
        success    = success,
        score      = score,
        source     = source,
        created_at = private$.now()
      )

      self$outcomes[[length(self$outcomes) + 1L]] <- record
      self$outcomes <- keep_last(self$outcomes, self$max_outcomes)
      private$.persist()

      invisible(record)
    },

    #' @description
    #' Retrieve the lessons most relevant to a query.
    #' @param query `[character(1)]` The task or prompt to find lessons for.
    #' @param k `[integerish(1)]` Maximum number of lessons to return. Default 3.
    #' @param agent_name `[character(1) | NULL]` When given, only lessons
    #'   learned by this agent are considered.
    #' @return A list of lesson records, most relevant first (possibly empty).
    search = function(query, k = 3, agent_name = NULL) {
      checkmate::assert_string(query)
      checkmate::assert_int(k, lower = 0)
      checkmate::assert_string(agent_name, null.ok = TRUE)

      candidates <- self$lessons
      if (!is.null(agent_name)) {
        candidates <- Filter(
          function(l) identical(l$agent_name, agent_name),
          candidates
        )
      }

      if (k == 0L || length(candidates) == 0L) return(list())

      if (!is.null(private$.search_fn)) {
        found <- private$.search_fn(query, candidates, k)
        found <- as.list(found)
        return(found[seq_len(min(k, length(found)))])
      }

      docs <- vapply(candidates, function(l) {
        paste(l$lesson, if (is.na(l$task)) "" else l$task)
      }, character(1))

      scores <- bm25_scores(query, docs)
      # Most recent first among equal scores.
      ord <- order(-scores, -seq_along(scores))
      ord <- ord[scores[ord] > 0]

      candidates[ord[seq_len(min(k, length(ord)))]]
    },

    #' @description
    #' Summarise the recorded outcomes per agent.
    #' @param agent_names `[character | NULL]` Agents to report on. Agents
    #'   with no recorded outcome get a row with `n_tasks = 0`. Defaults to
    #'   every agent that has an outcome.
    #' @return A data frame with columns `agent_name`, `n_tasks`,
    #'   `n_success`, `success_rate` and `mean_score`.
    track_record = function(agent_names = NULL) {
      checkmate::assert_character(agent_names, any.missing = FALSE, null.ok = TRUE)

      recorded <- vapply(self$outcomes, function(o) o$agent_name, character(1))
      if (is.null(agent_names)) agent_names <- unique(recorded)

      rows <- lapply(agent_names, function(name) {
        own <- self$outcomes[recorded == name]
        success <- vapply(own, function(o) isTRUE(o$success), logical(1))
        scores <- vapply(own, function(o) as.numeric(o$score), numeric(1))
        n <- length(own)
        data.frame(
          agent_name   = name,
          n_tasks      = n,
          n_success    = sum(success),
          success_rate = if (n > 0) mean(success) else NA_real_,
          mean_score   = if (any(!is.na(scores))) mean(scores, na.rm = TRUE) else NA_real_,
          stringsAsFactors = FALSE
        )
      })

      if (length(rows) == 0L) {
        return(data.frame(
          agent_name = character(0), n_tasks = integer(0),
          n_success = integer(0), success_rate = numeric(0),
          mean_score = numeric(0), stringsAsFactors = FALSE
        ))
      }

      do.call(rbind, rows)
    },

    #' @description
    #' Save the memory to a JSON file.
    #' @param path `[character(1)]` Destination file. Defaults to `$path`.
    #' @return Invisibly, `self`.
    save = function(path = self$path) {
      checkmate::assert_string(path)

      jsonlite::write_json(
        list(lessons = self$lessons, outcomes = self$outcomes),
        path = path,
        auto_unbox = TRUE,
        pretty = TRUE,
        na = "null",
        null = "null",
        digits = NA
      )

      invisible(self)
    },

    #' @description
    #' Load lessons and outcomes from a JSON file written by \code{$save()},
    #' replacing the current content.
    #' @param path `[character(1)]` Source file. Defaults to `$path`.
    #' @return Invisibly, `self`.
    load = function(path = self$path) {
      checkmate::assert_string(path)

      if (!file.exists(path)) {
        cli::cli_abort("Memory file {.file {path}} does not exist.")
      }

      content <- jsonlite::read_json(path, simplifyVector = FALSE)

      self$lessons <- lapply(content$lessons, normalize_record, defaults = list(
        id = NA_character_, lesson = NA_character_, task = NA_character_,
        agent_name = NA_character_, score = NA_real_, success = NA,
        created_at = NA_character_
      ))
      self$outcomes <- lapply(content$outcomes, normalize_record, defaults = list(
        agent_name = NA_character_, task = NA_character_, success = NA,
        score = NA_real_, source = NA_character_, created_at = NA_character_
      ))

      invisible(self)
    },

    #' @description
    #' Remove all lessons and outcomes (and save, when `$path` is set).
    #' @return Invisibly, `self`.
    clear = function() {
      self$lessons <- list()
      self$outcomes <- list()
      private$.persist()
      invisible(self)
    },

    #' @description
    #' Print a short summary of the memory.
    #' @param ... Ignored.
    print = function(...) {
      cli::cli_text("{.cls Memory}")
      cli::cli_text("Lessons: {length(self$lessons)}, outcomes: {length(self$outcomes)}")
      if (!is.null(self$path)) cli::cli_text("Saved to: {.file {self$path}}")
      invisible(self)
    }
  ),

  private = list(
    .search_fn = NULL,

    .persist = function() {
      if (!is.null(self$path)) self$save(self$path)
    },

    .now = function() {
      format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    }
  )
)

keep_last <- function(x, n) {
  if (length(x) <= n) return(x)
  x[seq.int(length(x) - n + 1L, length(x))]
}

# JSON turns NA into null, which read_json() gives back as NULL: put the
# defaults back so every record has the same fields with the same types.
normalize_record <- function(record, defaults) {
  for (field in names(defaults)) {
    if (is.null(record[[field]])) {
      record[[field]] <- defaults[[field]]
    }
  }
  # A whole-number score such as 1 comes back from JSON as an integer.
  if ("score" %in% names(record)) record$score <- as.numeric(record$score)
  record[names(defaults)]
}

memory_stopwords <- c(
  "the", "and", "for", "are", "but", "not", "you", "your", "with", "this",
  "that", "from", "they", "will", "would", "there", "their", "what", "about",
  "which", "when", "make", "can", "like", "into", "than", "then", "them",
  "these", "those", "some", "such", "only", "also", "its", "was", "were",
  "been", "being", "have", "has", "had", "does", "did", "doing", "should",
  "could", "each", "other", "more", "most", "very", "just", "over", "any",
  "all", "our", "out", "who", "how", "why", "where", "use", "using"
)

tokenize_text <- function(text) {
  tokens <- unlist(strsplit(tolower(text), "[^[:alnum:]]+"))
  tokens[nchar(tokens) >= 3 & !tokens %in% memory_stopwords]
}

# Okapi BM25 relevance of each document to the query.
bm25_scores <- function(query, docs, k1 = 1.2, b = 0.75) {
  query_tokens <- unique(tokenize_text(query))
  doc_tokens <- lapply(docs, tokenize_text)

  if (length(query_tokens) == 0L || length(docs) == 0L) {
    return(numeric(length(docs)))
  }

  doc_len <- lengths(doc_tokens)
  avg_len <- max(mean(doc_len), 1)
  n_docs <- length(docs)

  scores <- numeric(n_docs)
  for (term in query_tokens) {
    tf <- vapply(doc_tokens, function(tokens) sum(tokens == term), numeric(1))
    n_containing <- sum(tf > 0)
    if (n_containing == 0) next
    idf <- log(1 + (n_docs - n_containing + 0.5) / (n_containing + 0.5))
    scores <- scores + idf * tf * (k1 + 1) / (tf + k1 * (1 - b + b * doc_len / avg_len))
  }

  scores
}

# Prompt asking an LLM to turn one judged task into a reusable lesson. Shared
# by Agent$learn() and the LeadAgent HITL path.
lesson_prompt <- function(task, response, verdict) {
  paste0(
    "An AI agent performed the following task.\n\n",
    "Task:\n", task, "\n\n",
    "Agent response:\n", response, "\n\n",
    "Verdict:\n", verdict, "\n\n",
    "Write ONE reusable lesson, at most two sentences, for an agent facing similar ",
    "tasks in the future. If the outcome was good, state the strategy that made it work. ",
    "If it was bad, state what to avoid and what to do instead. Generalise: do not ",
    "mention details that only apply to this exact input. Return only the lesson."
  )
}

lesson_system_prompt <- paste0(
  "You distill experience into short, reusable lessons for AI agents. ",
  "You return only the lesson text, with no preamble."
)

# Prepend retrieved lessons to a prompt. Returns the prompt unchanged when
# there is nothing relevant.
prompt_with_lessons <- function(prompt, lessons) {
  if (length(lessons) == 0L) return(prompt)

  bullets <- vapply(lessons, function(l) paste0("- ", l$lesson), character(1))

  paste0(
    "Lessons learned from previous similar tasks (apply them when relevant):\n",
    paste(bullets, collapse = "\n"),
    "\n\n--- Task ---\n",
    prompt
  )
}
