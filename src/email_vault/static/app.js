"use strict";

(() => {
  const MASK = "••••••••";
  const PASSWORD_CHARS =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*-_=+";
  const PASSWORD_LENGTH = 20;

  async function fetchSecret(url) {
    const res = await fetch(url, { method: "POST", credentials: "same-origin" });
    if (res.status === 401) {
      location.href = "/unlock";
      throw new Error("locked");
    }
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return (await res.json()).password ?? "";
  }

  function toast(text, kind = "ok") {
    const box = document.querySelector("[data-toasts]") ?? document.body;
    const el = document.createElement("div");
    el.className = `toast ${kind}`;
    el.textContent = text;
    box.append(el);
    setTimeout(() => el.remove(), 2000);
  }

  async function copy(text) {
    try {
      await navigator.clipboard.writeText(text);
      toast("已复制到剪贴板");
    } catch {
      toast("复制失败", "err");
    }
  }

  function setIcon(btn, name) {
    btn.querySelector("use")?.setAttribute("href", `#i-${name}`);
  }

  // Unbiased random password via rejection sampling.
  function generatePassword() {
    const n = PASSWORD_CHARS.length;
    const limit = 256 - (256 % n);
    const out = [];
    while (out.length < PASSWORD_LENGTH) {
      for (const b of crypto.getRandomValues(new Uint8Array(PASSWORD_LENGTH * 2))) {
        if (b < limit && out.length < PASSWORD_LENGTH) out.push(PASSWORD_CHARS[b % n]);
      }
    }
    return out.join("");
  }

  function openDialog(btn) {
    const dialog = document.getElementById(btn.dataset.openDialog);
    const form = dialog.querySelector("form");
    form.reset();
    form.action = btn.dataset.action;
    dialog.querySelector("[data-dialog-title]").textContent = btn.dataset.title ?? "";
    for (const [name, value] of Object.entries(JSON.parse(btn.dataset.fields || "{}"))) {
      if (form.elements[name]) form.elements[name].value = value;
    }
    for (const input of form.querySelectorAll("[data-password-input]")) {
      input.type = "password";
      input.placeholder = btn.dataset.passwordHint ?? "";
    }
    for (const toggle of form.querySelectorAll("[data-toggle-password]")) setIcon(toggle, "eye");
    for (const input of form.querySelectorAll("[data-platform-input]")) {
      closeSuggest(input);
      delete input.dataset.autoUrl;
    }
    dialog.showModal();
    form.querySelector("input:not([type=hidden])")?.focus();
  }

  const VIEW_KEY = "email-vault:view";

  function applyView(view) {
    for (const grid of document.querySelectorAll("[data-view-target]")) {
      grid.classList.toggle("is-list", view === "list");
    }
    for (const seg of document.querySelectorAll("[data-view]")) {
      seg.classList.toggle("active", seg.dataset.view === view);
    }
  }

  try {
    applyView(localStorage.getItem(VIEW_KEY) === "list" ? "list" : "grid");
  } catch {
    applyView("grid");
  }

  const handlers = {
    async reveal(btn) {
      const code = btn.closest(".secret").querySelector("[data-secret]");
      if (code.dataset.revealed) {
        code.textContent = MASK;
        delete code.dataset.revealed;
        setIcon(btn, "eye");
        btn.title = "显示";
        return;
      }
      code.textContent = await fetchSecret(btn.dataset.reveal);
      code.dataset.revealed = "1";
      setIcon(btn, "eye-off");
      btn.title = "隐藏";
    },
    async copySecret(btn) {
      await copy(await fetchSecret(btn.dataset.copySecret));
    },
    async copyText(btn) {
      await copy(btn.dataset.copyText);
    },
    view(btn) {
      applyView(btn.dataset.view);
      try {
        localStorage.setItem(VIEW_KEY, btn.dataset.view);
      } catch {
        // storage unavailable (private mode etc.): the choice just won't persist
      }
    },
    filter(btn) {
      const value = btn.dataset.filter;
      for (const chip of document.querySelectorAll("[data-filter]")) {
        chip.classList.toggle("active", chip === btn);
      }
      for (const card of document.querySelectorAll(".svc[data-category]")) {
        card.hidden = value !== "all" && card.dataset.category !== value;
      }
    },
    openDialog,
    closeDialog(btn) {
      btn.closest("dialog").close();
    },
    togglePassword(btn) {
      const input = btn.closest(".pw-row").querySelector("input");
      input.type = input.type === "password" ? "text" : "password";
      setIcon(btn, input.type === "password" ? "eye" : "eye-off");
    },
    generatePassword(btn) {
      const input = btn.closest(".pw-row").querySelector("input");
      input.value = generatePassword();
      input.type = "text";
      setIcon(btn.parentElement.querySelector("[data-toggle-password]"), "eye-off");
    },
  };

  document.addEventListener("click", (event) => {
    for (const [name, handler] of Object.entries(handlers)) {
      const attr = `data-${name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`;
      const btn = event.target.closest(`[${attr}]`);
      if (btn) {
        event.preventDefault();
        Promise.resolve(handler(btn)).catch((err) => console.error(err));
        return;
      }
    }
  });

  document.addEventListener("submit", (event) => {
    const message = event.target.dataset.confirm;
    if (message && !confirm(message)) event.preventDefault();
  });

  // ---- platform autocomplete ---------------------------------------------

  const SUGGEST_LIMIT = 8;
  const catalogEl = document.getElementById("platform-catalog");
  const catalog = catalogEl ? JSON.parse(catalogEl.textContent) : [];
  const norm = (text) => text.toLowerCase().replace(/\s+/g, "");

  // 0: name prefix, 1: alias prefix, 2: substring anywhere; null: no match.
  function score(entry, q) {
    const name = norm(entry.name);
    if (name.startsWith(q)) return 0;
    if (entry.keys.some((k) => k.startsWith(q))) return 1;
    if (entry.keys.some((k) => k.includes(q))) return 2;
    return null;
  }

  function matches(query) {
    const q = norm(query);
    if (!q) return [];
    return catalog
      .map((entry) => ({ entry, s: score(entry, q) }))
      // A single character only matches name prefixes; aliases are too noisy there.
      .filter((m) => m.s !== null && (q.length > 1 || m.s === 0))
      .sort((a, b) => a.s - b.s || Number(!a.entry.mine) - Number(!b.entry.mine) ||
        a.entry.name.localeCompare(b.entry.name))
      .slice(0, SUGGEST_LIMIT)
      .map((m) => m.entry);
  }

  function svgUse(href) {
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("aria-hidden", "true");
    const use = document.createElementNS(ns, "use");
    use.setAttribute("href", href);
    svg.append(use);
    return svg;
  }

  function suggestItem(entry, form) {
    const li = document.createElement("li");
    li.setAttribute("role", "option");
    const avatar = document.createElement("span");
    if (entry.logo) {
      avatar.className = "avatar sm logo";
      avatar.append(svgUse(`#brand-${entry.logo}`));
    } else {
      avatar.className = "avatar sm av-plain";
      avatar.textContent = entry.name.slice(0, 1).toUpperCase();
    }
    const name = document.createElement("span");
    name.className = "suggest-name";
    name.textContent = entry.name;
    const tag = document.createElement("span");
    tag.className = `tag tag-${entry.category}`;
    tag.textContent =
      form.elements.category?.querySelector(`option[value="${entry.category}"]`)?.textContent ??
      entry.category;
    const host = document.createElement("span");
    host.className = "suggest-host";
    host.textContent = entry.mine ? "已用过" : entry.url.replace(/^https?:\/\//, "");
    li.append(avatar, name, tag, host);
    return li;
  }

  function closeSuggest(input) {
    const list = document.getElementById(input.getAttribute("aria-controls"));
    list.hidden = true;
    list.replaceChildren();
    input.setAttribute("aria-expanded", "false");
    input.removeAttribute("aria-activedescendant");
  }

  function setActive(list, index) {
    const items = [...list.children];
    if (!items.length) return;
    const next = (index + items.length) % items.length;
    items.forEach((li, i) => li.classList.toggle("active", i === next));
    items[next].scrollIntoView({ block: "nearest" });
    list.dataset.active = String(next);
  }

  function pick(input, entry) {
    const form = input.form;
    input.value = entry.name;
    if (form.elements.category) form.elements.category.value = entry.category;
    const url = form.elements.url;
    // Fill the URL unless the user typed their own.
    if (url && (!url.value || url.value === input.dataset.autoUrl)) {
      url.value = entry.url;
      input.dataset.autoUrl = entry.url;
    }
    closeSuggest(input);
  }

  function openSuggest(input) {
    const list = document.getElementById(input.getAttribute("aria-controls"));
    const found = matches(input.value);
    list.replaceChildren();
    if (!found.length) {
      closeSuggest(input);
      return;
    }
    for (const entry of found) {
      const li = suggestItem(entry, input.form);
      li.addEventListener("mousedown", (event) => {
        event.preventDefault(); // keep focus in the input
        pick(input, entry);
      });
      list.append(li);
    }
    list._entries = found;
    list.hidden = false;
    input.setAttribute("aria-expanded", "true");
    setActive(list, 0);
  }

  for (const input of document.querySelectorAll("[data-platform-input]")) {
    const list = document.getElementById(input.getAttribute("aria-controls"));
    input.addEventListener("input", () => openSuggest(input));
    input.addEventListener("blur", () => closeSuggest(input));
    input.addEventListener("keydown", (event) => {
      if (list.hidden) {
        if (event.key === "ArrowDown") openSuggest(input);
        return;
      }
      const active = Number(list.dataset.active ?? 0);
      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        setActive(list, active + (event.key === "ArrowDown" ? 1 : -1));
      } else if (event.key === "Enter" || event.key === "Tab") {
        if (event.key === "Enter") event.preventDefault();
        pick(input, list._entries[active]);
      } else if (event.key === "Escape") {
        event.preventDefault(); // close the list, not the dialog
        event.stopPropagation();
        closeSuggest(input);
      }
    });
  }

  // Drop one-shot flash params from the URL and fade the banners.
  const url = new URL(location.href);
  if (url.searchParams.has("msg") || url.searchParams.has("err")) {
    url.searchParams.delete("msg");
    url.searchParams.delete("err");
    history.replaceState(null, "", url);
  }
  setTimeout(() => {
    for (const el of document.querySelectorAll(".toast.ok")) el.remove();
  }, 4000);

  // Mirror the server-side idle lock so revealed secrets don't linger on screen.
  if (document.body.hasAttribute("data-unlocked")) {
    const timeout = Number(document.body.dataset.idleTimeout) + 1000;
    let timer;
    const reset = () => {
      clearTimeout(timer);
      timer = setTimeout(() => location.reload(), timeout);
    };
    for (const ev of ["mousemove", "keydown", "click", "scroll"]) {
      document.addEventListener(ev, reset, { passive: true });
    }
    reset();
  }
})();
