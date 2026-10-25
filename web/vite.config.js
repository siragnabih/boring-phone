import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const page = fileURLToPath(new URL("../ui/index.html", import.meta.url));

// The hosted site is ui/index.html (the page ui.py serves) plus the WebUSB backend.
// web/index.html is only a placeholder; this swaps in the real page at dev and build time.
const usePage = {
  name: "boring-phone-page",
  transformIndexHtml: {
    order: "pre",
    handler: () =>
      readFileSync(page, "utf8").replace(
        "</body>",
        '<script type="module" src="/src/webusb.js"></script>\n</body>',
      ),
  },
  configureServer(server) {
    server.watcher.add(page);
    server.watcher.on("change", (file) => {
      if (file === page) server.ws.send({ type: "full-reload" });
    });
  },
};

export default defineConfig({
  plugins: [usePage],
  build: { target: "es2022" },
});
