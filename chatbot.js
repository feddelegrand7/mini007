/* mini007 docs chatbot widget.
 *
 * Adds a chat button to every page of the site. Questions go to the
 * mini007-chat Cloudflare Worker (chatbot/ in the repository), which holds
 * the OpenAI key and the bot's rules; nothing secret lives in this file.
 */
(function () {
  "use strict";

  var ENDPOINT = "https://mini007-chat.mini007.workers.dev/chat";
  var STORAGE_KEY = "mini007-chat-history";
  var MAX_QUESTION_CHARS = 600;
  var MAX_HISTORY_SENT = 6;
  var WELCOME =
    "Hi! I can answer questions about mini007: its agents, workflows, tools and examples.";
  var SUGGESTIONS = [
    "What is a ReActAgent?",
    "How do I set a budget on an agent?",
    "When should I use a RouterAgent instead of a LeadAgent?",
  ];

  if (window.__mini007Chat) return;
  window.__mini007Chat = true;

  var ICONS = {
    chat:
      '<svg class="m7c-icon-chat" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/><path d="M8.5 11h.01M12 11h.01M15.5 11h.01"/></svg>',
    close:
      '<svg class="m7c-icon-close" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>',
    send:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
    reset:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/></svg>',
  };

  // ---- Load the stylesheet next to this script --------------------------
  var script = document.currentScript;
  var base = script && script.src ? script.src.replace(/[^/]*$/, "") : "";
  var link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = base + "chatbot.css";
  document.head.appendChild(link);

  // ---- State ------------------------------------------------------------
  var history = loadHistory();
  var busy = false;

  // ---- Markup -----------------------------------------------------------
  var root = document.createElement("div");
  root.className = "m7c-root";
  root.innerHTML =
    '<button type="button" class="m7c-launcher" aria-label="Open the mini007 assistant" aria-expanded="false" aria-controls="m7c-panel">' +
    ICONS.chat + ICONS.close +
    "</button>" +
    '<section class="m7c-panel" id="m7c-panel" role="dialog" aria-label="mini007 assistant">' +
    '<header class="m7c-header">' +
    '<div class="m7c-avatar" aria-hidden="true">007</div>' +
    '<div><div class="m7c-title">mini007 assistant</div><div class="m7c-subtitle">Answers from the documentation</div></div>' +
    '<div class="m7c-header-actions">' +
    '<button type="button" class="m7c-icon-button m7c-reset" aria-label="Start a new conversation" title="New conversation">' + ICONS.reset + "</button>" +
    "</div>" +
    "</header>" +
    '<div class="m7c-messages" aria-live="polite"></div>' +
    '<form class="m7c-form">' +
    '<textarea class="m7c-input" rows="1" maxlength="' + MAX_QUESTION_CHARS + '" placeholder="Ask about mini007..." aria-label="Your question"></textarea>' +
    '<button type="submit" class="m7c-send" aria-label="Send">' + ICONS.send + "</button>" +
    "</form>" +
    '<div class="m7c-footnote">AI answers can be wrong: check the docs for details.</div>' +
    "</section>";

  var launcher = root.querySelector(".m7c-launcher");
  var panel = root.querySelector(".m7c-panel");
  var list = root.querySelector(".m7c-messages");
  var form = root.querySelector(".m7c-form");
  var input = root.querySelector(".m7c-input");
  var send = root.querySelector(".m7c-send");
  var reset = root.querySelector(".m7c-reset");

  function mount() {
    document.body.appendChild(root);
    render();
  }

  // ---- Behaviour --------------------------------------------------------
  function setOpen(open) {
    root.classList.toggle("m7c-open", open);
    launcher.setAttribute("aria-expanded", String(open));
    launcher.setAttribute("aria-label", open ? "Close the mini007 assistant" : "Open the mini007 assistant");
    if (open) {
      setTimeout(function () { input.focus(); }, 150);
      scrollToEnd();
    }
  }

  launcher.addEventListener("click", function () {
    setOpen(!root.classList.contains("m7c-open"));
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && root.classList.contains("m7c-open")) {
      setOpen(false);
      launcher.focus();
    }
  });

  reset.addEventListener("click", function () {
    history = [];
    saveHistory();
    render();
    input.focus();
  });

  input.addEventListener("input", autoGrow);
  input.addEventListener("keydown", function (event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      form.requestSubmit ? form.requestSubmit() : submit();
    }
  });

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    submit();
  });

  function submit(text) {
    var question = (typeof text === "string" ? text : input.value).trim();
    if (!question || busy) return;
    if (question.length > MAX_QUESTION_CHARS) question = question.slice(0, MAX_QUESTION_CHARS);

    input.value = "";
    autoGrow();
    history.push({ role: "user", content: question });
    saveHistory();
    render();
    ask();
  }

  function ask() {
    busy = true;
    send.disabled = true;
    var typing = document.createElement("div");
    typing.className = "m7c-typing";
    typing.setAttribute("aria-label", "The assistant is typing");
    typing.innerHTML = "<span></span><span></span><span></span>";
    list.appendChild(typing);
    scrollToEnd();

    var messages = history
      .filter(function (m) { return m.role === "user" || m.role === "assistant"; })
      .slice(-MAX_HISTORY_SENT);

    fetch(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ messages: messages }),
    })
      .then(function (response) {
        return response.json().catch(function () { return {}; }).then(function (data) {
          if (!response.ok || !data.answer) {
            throw new Error(data.error || "The assistant is not available right now.");
          }
          return data.answer;
        });
      })
      .then(function (answer) {
        history.push({ role: "assistant", content: answer });
      })
      .catch(function (error) {
        var message = error && error.message && error.message !== "Failed to fetch"
          ? error.message
          : "Could not reach the assistant. Please check your connection and try again.";
        history.push({ role: "error", content: message });
      })
      .then(function () {
        busy = false;
        send.disabled = false;
        saveHistory();
        render();
        input.focus();
      });
  }

  // ---- Rendering --------------------------------------------------------
  function render() {
    list.innerHTML = "";
    addMessage("assistant", WELCOME);

    if (history.length === 0) {
      var chips = document.createElement("div");
      chips.className = "m7c-suggestions";
      SUGGESTIONS.forEach(function (suggestion) {
        var chip = document.createElement("button");
        chip.type = "button";
        chip.className = "m7c-chip";
        chip.textContent = suggestion;
        chip.addEventListener("click", function () { submit(suggestion); });
        chips.appendChild(chip);
      });
      list.appendChild(chips);
    }

    history.forEach(function (m) { addMessage(m.role, m.content); });
    scrollToEnd();
  }

  function addMessage(role, content) {
    var bubble = document.createElement("div");
    bubble.className =
      "m7c-msg " + (role === "user" ? "m7c-msg-user" : role === "error" ? "m7c-msg-error" : "m7c-msg-bot");
    if (role === "assistant") {
      bubble.innerHTML = formatAnswer(content);
    } else {
      bubble.textContent = content;
    }
    list.appendChild(bubble);
  }

  // Minimal, safe Markdown: the text is escaped first, then `code`,
  // **bold** and links to this site are turned back into HTML.
  function formatAnswer(text) {
    var html = escapeHtml(text);
    html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
    html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    html = html.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (match, label, url) {
      return isSafeUrl(url) ? '<a href="' + url + '">' + label + "</a>" : label;
    });
    return html;
  }

  function isSafeUrl(url) {
    return /^https:\/\/feddelegrand7\.github\.io\/mini007\//.test(url) ||
      /^https:\/\/github\.com\/feddelegrand7\/mini007/.test(url) ||
      /^[a-z0-9-]+\.html(#[\w-]+)?$/i.test(url);
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function scrollToEnd() {
    list.scrollTop = list.scrollHeight;
  }

  function autoGrow() {
    input.style.height = "auto";
    input.style.height = Math.min(input.scrollHeight, 110) + "px";
  }

  // The conversation survives page changes within the tab.
  function loadHistory() {
    try {
      var saved = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || "[]");
      return Array.isArray(saved) ? saved.slice(-20) : [];
    } catch (e) {
      return [];
    }
  }

  function saveHistory() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(history.slice(-20)));
    } catch (e) { /* storage unavailable: keep the conversation in memory */ }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mount);
  } else {
    mount();
  }
})();
