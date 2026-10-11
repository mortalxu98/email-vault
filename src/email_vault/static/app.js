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
    dialog.showModal();
    form.querySelector("input:not([type=hidden])")?.focus();
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
