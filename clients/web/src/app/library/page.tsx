import type { Metadata } from "next";
import { LibraryView, type LibraryGridGame } from "@/components/library/LibraryView";
import { getSnapshot } from "@/lib/data";

export const metadata: Metadata = { title: "Library" };

export default function Library() {
  const { library } = getSnapshot();
  const games: LibraryGridGame[] = library.games.map((g) => ({
    appId: g.appId,
    name: g.name,
    images: g.images,
    installed: g.installed,
    updateAvailable: g.updateAvailable,
    lastPlayed: g.lastPlayed,
    lastPlayedLabel: g.lastPlayedLabel,
    playtimeMinutes: g.playtimeMinutes,
    playtimeLabel: g.playtimeLabel,
  }));
  return (
    <div className="page page--library page--flush">
      <LibraryView games={games} collections={library.collections} recentAppIds={library.recentAppIds} />
    </div>
  );
}
