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
    "Hi, I'm Robert! Ask me anything about mini007: its agents, workflows, tools and examples.";
  var SUGGESTIONS = [
    "What is a ReActAgent?",
    "How do I set a budget on an agent?",
    "When should I use a RouterAgent instead of a LeadAgent?",
  ];

  if (window.__mini007Chat) return;
  window.__mini007Chat = true;

  // Robert: the assistant's face, with sunglasses and a bow tie.
  var ROBERT = '<svg class="m7c-robert" viewBox="0 0 64 64" aria-hidden="true"><defs><linearGradient id="m7c-lens" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#334155"/><stop offset="1" stop-color="#020617"/></linearGradient></defs><circle cx="11.6" cy="34" r="3.6" fill="#F2B98E"/><circle cx="52.4" cy="34" r="3.6" fill="#F2B98E"/><circle cx="32" cy="32" r="20.5" fill="#FFD7B5"/><path d="M12.2 27.5 C11.4 15 20.8 7.6 33 7.6 C45.2 7.6 54 15.2 52.2 27 C48.6 19.6 42 16.2 34.4 16.6 C29 16.9 26.6 14.6 25.4 13.4 C22.6 17.6 17.2 21 12.2 27.5 Z" fill="#1F2937"/><path d="M34 9.4 C40 10.2 44.6 13.2 46.4 17" stroke="#475569" stroke-width="1.6" fill="none" stroke-linecap="round"/><path d="M12.6 29.4 H51.4" stroke="#0F172A" stroke-width="2.4" stroke-linecap="round"/><rect x="14.2" y="27.4" width="15.6" height="10.6" rx="4.8" fill="url(#m7c-lens)"/><rect x="34.2" y="27.4" width="15.6" height="10.6" rx="4.8" fill="url(#m7c-lens)"/><path d="M17.6 31.4 L21.8 29.4 M37.6 31.4 L41.8 29.4" stroke="#fff" stroke-opacity=".8" stroke-width="1.7" stroke-linecap="round"/><path d="M26.2 44.2 Q32.6 48.6 38.6 43.4" stroke="#7C2D12" stroke-width="2.3" fill="none" stroke-linecap="round"/><path d="M23.4 55 L31 58.6 L23.4 62.2 Z M40.6 55 L33 58.6 L40.6 62.2 Z" fill="#0F172A"/><rect x="29.8" y="56.6" width="4.4" height="4" rx="1.4" fill="#0F172A"/></svg>';

  var ICONS = {
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
    '<button type="button" class="m7c-launcher" aria-label="Chat with Robert, the mini007 assistant" aria-expanded="false" aria-controls="m7c-panel">' +
    '<span class="m7c-launcher-face">' + ROBERT + "</span>" + ICONS.close +
    "</button>" +
    '<section class="m7c-panel" id="m7c-panel" role="dialog" aria-label="Robert, the mini007 assistant">' +
    '<header class="m7c-header">' +
    '<div class="m7c-avatar">' + ROBERT + "</div>" +
    '<div><div class="m7c-title">Robert</div><div class="m7c-subtitle">mini007 assistant · answers from the docs</div></div>' +
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
    launcher.setAttribute("aria-label", open ? "Close the chat with Robert" : "Chat with Robert, the mini007 assistant");
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
    var typing = botRow();
    var dots = document.createElement("div");
    dots.className = "m7c-typing";
    dots.setAttribute("aria-label", "Robert is typing");
    dots.innerHTML = "<span></span><span></span><span></span>";
    typing.appendChild(dots);
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
    if (role === "user") {
      list.appendChild(bubble);
    } else {
      var row = botRow();
      row.appendChild(bubble);
      list.appendChild(row);
    }
  }

  // A row for Robert's messages: his face, then the bubble.
  function botRow() {
    var row = document.createElement("div");
    row.className = "m7c-row";
    var face = document.createElement("div");
    face.className = "m7c-row-avatar";
    face.innerHTML = ROBERT;
    row.appendChild(face);
    return row;
  }

  // Minimal, safe Markdown. Everything is escaped first; then fenced code
  // blocks, `inline code`, **bold**, line breaks and links to this site are
  // turned back into HTML.
  function formatAnswer(text) {
    var parts = String(text).split(/```[a-zA-Z]*\n?([\s\S]*?)```/);
    return parts.map(function (part, i) {
      if (i % 2 === 1) {
        return '<pre class="m7c-code"><code>' + escapeHtml(part.replace(/\n+$/, "")) + "</code></pre>";
      }
      var html = escapeHtml(part.trim());
      if (!html) return "";
      html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
      html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
      html = html.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (match, label, url) {
        return isSafeUrl(url) ? '<a href="' + url + '">' + label + "</a>" : label;
      });
      return "<p>" + html.replace(/\n{2,}/g, "</p><p>").replace(/\n/g, "<br>") + "</p>";
    }).join("");
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
