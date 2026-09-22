(() => {
  "use strict";
  const base = JSON.parse(document.getElementById("prompt-source").textContent);
  const brief = document.getElementById("shape-brief");
  const preview = document.getElementById("prompt-text");
  const copy = document.getElementById("copy-prompt");
  const download = document.getElementById("download-prompt");
  const status = document.getElementById("copy-status");
  const marker = "\nSHAPE BRIEF\n";
  let resetLabel;

  function fullPrompt() {
    const description = brief.value.trim();
    return description ? base.slice(0, base.lastIndexOf(marker)) + marker + description + "\n" : base;
  }
  function refresh() {
    preview.value = fullPrompt();
    copy.textContent = "Copy full LLM prompt";
    status.textContent = "Your description is added locally. Copying does not send it to an AI.";
  }
  brief.addEventListener("input", refresh);
  copy.addEventListener("click", async () => {
    clearTimeout(resetLabel);
    preview.value = fullPrompt();
    let copied = false;
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(preview.value);
        copied = true;
      }
    } catch (_) { /* Fall back to selecting visible text below. */ }
    if (!copied) {
      const details = preview.closest("details");
      details.open = true;
      preview.focus();
      preview.select();
      preview.setSelectionRange(0, preview.value.length);
      try { copied = document.execCommand("copy"); } catch (_) {}
    }
    copy.textContent = copied ? "Prompt copied" : "Prompt selected";
    status.textContent = copied
      ? "Copied. Paste the prompt into your AI to create the shape."
      : "Automatic copying is unavailable. Copy the selected prompt, or download the text file.";
    resetLabel = setTimeout(() => { copy.textContent = "Copy full LLM prompt"; }, 2500);
  });
  download.addEventListener("click", () => {
    const url = URL.createObjectURL(new Blob([fullPrompt()], { type: "text/plain;charset=utf-8" }));
    download.href = url;
    download.download = "project-gravity-shape-prompt.txt";
    setTimeout(() => { URL.revokeObjectURL(url); download.href = "plugin-prompt.txt"; }, 1000);
  });
  refresh();
})();
