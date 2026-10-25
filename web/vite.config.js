import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const page = fileURLToPath(new URL("../ui/index.html", import.meta.url));

// Link previews (WhatsApp, iMessage, Slack…) need absolute URLs. Vercel tells the build its address.
const site = "https://" + (process.env.VERCEL_PROJECT_PRODUCTION_URL || "boring-phone-kxhc.vercel.app");
const description =
  "Quita redes sociales, navegadores, juegos y apps de relleno de un móvil Android desde el navegador. Gratis y reversible. · " +
  "Remove social media, browsers, games and junk apps from an Android phone, right from your browser. Free and reversible.";
const shareTags = `
<meta name="description" content="${description}">
<meta name="theme-color" content="#f3efe6">
<meta property="og:type" content="website">
<meta property="og:url" content="${site}/">
<meta property="og:title" content="Clean Phone · Make it clean · Déjalo limpio">
<meta property="og:description" content="${description}">
<meta property="og:image" content="${site}/og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="Make it clean. TikTok, YouTube, Instagram and Candy Crush crossed out; WhatsApp and Maps kept.">
<meta name="twitter:card" content="summary_large_image">`;

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
        .replace("</title>", "</title>" + shareTags)
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
