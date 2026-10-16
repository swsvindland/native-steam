import type { NextConfig } from "next";

// Static export so the client can be hosted on GitHub Pages.
// BASE_PATH is set by CI (e.g. "/native-steam"); empty for local dev.
const basePath = (process.env.BASE_PATH ?? "").replace(/\/$/, "");

const nextConfig: NextConfig = {
  output: "export",
  basePath: basePath || undefined,
  trailingSlash: true,
  images: { unoptimized: true },
  reactStrictMode: true,
  poweredByHeader: false,
  // Don't let `next dev` write an AGENTS.md into the client.
  agentRules: false,
};

export default nextConfig;
