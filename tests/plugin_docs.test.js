const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const site = path.resolve(__dirname, "../docs/plugins");
const html = fs.readFileSync(path.join(site, "index.html"), "utf8");
const source = html.match(/<script id="prompt-source" type="application\/json">([\s\S]*?)<\/script>/)[1];
const prompt = fs.readFileSync(path.join(site, "plugin-prompt.txt"), "utf8");
assert.equal(JSON.parse(source), prompt, "copied and downloadable specifications must match");
const code = fs.readFileSync(path.join(site, "guide.js"), "utf8");

function page(clipboardWorks, fallbackWorks = false) {
  const elements = {};
  for (const id of ["prompt-source", "shape-brief", "prompt-text", "copy-prompt", "download-prompt", "copy-status"]) {
    elements[id] = {
      value: "", textContent: id === "prompt-source" ? source : "", listeners: {},
      addEventListener(event, callback) { this.listeners[event] = callback; },
      focus() { this.focused = true; }, select() { this.selected = true; },
      setSelectionRange(start, end) { this.selection = [start, end]; },
      closest() { return this.details ||= { open: false }; },
    };
  }
  const result = { elements };
  vm.runInNewContext(code, {
    document: { getElementById: id => elements[id], execCommand: () => fallbackWorks },
    window: { isSecureContext: true },
    navigator: { clipboard: { writeText: async text => {
      if (!clipboardWorks) throw new Error("clipboard unavailable");
      result.copied = text;
    } } },
    Blob: class { constructor(parts) { result.downloaded = parts.join(""); } },
    URL: { createObjectURL: () => "blob:prompt", revokeObjectURL() {} },
    setTimeout() { return 1; }, clearTimeout() {},
  });
  return result;
}

(async () => {
  const normal = page(true);
  assert.equal(normal.elements["prompt-text"].value, prompt);
  normal.elements["shape-brief"].value = "A phoenix with a mobile dash button. <script>literal brief</script>";
  normal.elements["shape-brief"].listeners.input();
  await normal.elements["copy-prompt"].listeners.click();
  assert.ok(normal.copied.endsWith(normal.elements["shape-brief"].value + "\n"), "custom brief is appended as plain text");
  assert.ok(normal.copied.includes('Type = "Button"') && normal.copied.includes("M.MobileControls"));
  assert.ok(!normal.copied.includes("[Describe the shape"), "custom brief replaces placeholder");
  assert.match(normal.elements["copy-status"].textContent, /^Copied/);
  normal.elements["download-prompt"].listeners.click();
  assert.equal(normal.downloaded, normal.copied, "download includes the same custom brief");
  const fallback = page(false, true);
  await fallback.elements["copy-prompt"].listeners.click();
  assert.ok(fallback.elements["prompt-text"].selected && fallback.elements["prompt-text"].details.open);
  assert.match(fallback.elements["copy-status"].textContent, /^Copied/);
  const manual = page(false, false);
  await manual.elements["copy-prompt"].listeners.click();
  assert.match(manual.elements["copy-status"].textContent, /Copy the selected prompt/);
  for (const match of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    const link = match[1];
    if (/^https?:/.test(link)) continue;
    if (link.startsWith("#")) {
      assert.ok(html.includes('id="' + link.slice(1) + '"'), "anchor exists: " + link);
    } else {
      assert.ok(fs.existsSync(path.resolve(site, link)), "local link exists: " + link);
    }
  }
  console.log("Plugin docs: prompt sync, custom brief, clipboard, fallback, download and links passed.");
})().catch(error => { console.error(error); process.exitCode = 1; });
