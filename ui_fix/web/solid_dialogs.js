import { app } from "../../scripts/app.js";

const style = document.createElement("style");
style.textContent = `.p-dialog.global-dialog.cdc-solid{background:var(--comfy-menu-bg,#171718);border:1px solid var(--border-color,#4e4e4e);border-radius:12px;box-shadow:0 10px 40px rgba(0,0,0,.6);padding:24px;box-sizing:content-box}`;
document.head.appendChild(style);

// Only a dialog that came out transparent gets the background; the frontend's own dialogs already have one.
function solidify(el) {
  if (!(el instanceof HTMLElement)) return;
  const dialogs = el.matches(".p-dialog.global-dialog") ? [el] : [...el.querySelectorAll(".p-dialog.global-dialog")];
  for (const d of dialogs) {
    if (getComputedStyle(d).backgroundColor === "rgba(0, 0, 0, 0)") d.classList.add("cdc-solid");
  }
}

app.registerExtension({
  name: "Candidcore.SolidDialogs",
  setup() {
    new MutationObserver((records) => {
      for (const r of records) r.addedNodes.forEach(solidify);
    }).observe(document.body, { childList: true, subtree: true });
  },
});
