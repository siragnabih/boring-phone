import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const page = fileURLToPath(new URL("../ui/index.html", import.meta.url));

// The hosted site is ui/index.html (the page ui.py serves) plus the WebUSB backend,
// with the Google Fonts links swapped for fonts served from the site itself.
// web/index.html is only a placeholder; this swaps in the real page at dev and build time.
const usePage = {
  name: "clean-phone-page",
  transformIndexHtml: {
    order: "pre",
    handler: () => {
      const html = readFileSync(page, "utf8")
        .replace(/^<link [^>]*fonts\.(googleapis|gstatic)\.com[^>]*>\n/gm, "")
        .replace("</head>", '<link rel="stylesheet" href="/src/fonts.css">\n</head>')
        .replace("</body>", '<script type="module" src="/src/webusb.js"></script>\n</body>');
      if (html.includes("fonts.googleapis.com")) throw new Error("Google Fonts link left in the hosted page");
      return html;
    },
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
