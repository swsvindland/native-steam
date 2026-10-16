import type { Metadata, Viewport } from "next";
import { Shell } from "@/components/shell/Shell";
import { INPUT_BOOT_SCRIPT } from "@/components/shell/InputContext";
import { getSnapshot } from "@/lib/data";
import "./styles/tokens.css";
import "./styles/base.css";
import "./styles/shell.css";
import "./styles/components.css";
import "./styles/store.css";
import "./styles/library.css";
import "./styles/community.css";
import "./styles/profile.css";

export const metadata: Metadata = {
  title: { default: "Native Steam", template: "%s · Native Steam" },
  description:
    "An unofficial concept: what a fully native Steam client could look like — one adaptive UI for mouse & keyboard, touch and gamepad. Not affiliated with Valve.",
};

export const viewport: Viewport = {
  themeColor: "#171a21",
  colorScheme: "dark",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const { user, friends, library } = getSnapshot();
  const online = friends.filter((f) => f.status !== "offline").length;
  const inGame = friends.filter((f) => f.status === "inGame").length;
  return (
    <html lang="en" data-input="mouse" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: INPUT_BOOT_SCRIPT }} />
        <link rel="preconnect" href="https://shared.akamai.steamstatic.com" crossOrigin="" />
      </head>
      <body>
        <Shell
          user={{ personaName: user.personaName, avatarUrl: user.avatarUrl, friendsOnline: online, friendsInGame: inGame }}
          initialFavorites={library.games.filter((g) => g.favorite).map((g) => g.appId)}
        >
          {children}
        </Shell>
      </body>
    </html>
  );
}
