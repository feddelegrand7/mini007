# mini007 docs chatbot

The chat button on the documentation site sends questions to a small
Cloudflare Worker (`src/index.js`). The Worker holds the OpenAI key as a
secret, adds the system prompt and the whole documentation, and enforces the
rules: mini007 questions only, at most 3 sentences, short conversations, and
8 questions per minute per visitor. The key never reaches the website.

The website side is `chatbot.js` and `chatbot.css` at the root of the
repository. Quarto copies them into `docs/` and adds the script to every page
(see `_quarto.yml`).

## Deploy

```sh
cd chatbot
npx wrangler login                       # once
npx wrangler secret put OPENAI_API_KEY   # once, or to change the key
npx wrangler deploy
```

`npx wrangler deploy` prints the Worker's URL; `ENDPOINT` in `chatbot.js`
must point to it, followed by `/chat`.

## When the documentation changes

The bot only knows what is in `src/knowledge.js`. Rebuild it from the site's
pages and redeploy:

```sh
node chatbot/build-knowledge.mjs
cd chatbot && npx wrangler deploy
```

## Settings

- `src/index.js`: model, system prompt, answer length, conversation limits.
- `wrangler.toml`: allowed origins and the rate limit.
- Set a monthly spending limit on the OpenAI project that owns the key.
