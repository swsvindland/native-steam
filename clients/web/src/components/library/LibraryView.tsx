"use client";

import Link from "next/link";
import { Download, Search, Star, X } from "lucide-react";
import { useMemo, useState } from "react";
import type { Collection, Images } from "@/lib/types";
import { usePaging } from "../shell/NavContext";
import { useUserState } from "../shell/UserState";
import { Art } from "../ui/Art";
import { PageTitle, SectionHeader } from "../ui/bits";
import { Shelf } from "../ui/Shelf";

export interface LibraryGridGame {
  appId: number;
  name: string;
  images: Images;
  installed: boolean;
  updateAvailable: boolean;
  lastPlayed: string | null;
  lastPlayedLabel: string;
  playtimeMinutes: number;
  playtimeLabel: string;
}

type SortKey = "alpha" | "recent" | "hours";
const SORTS: { id: SortKey; label: string; short: string }[] = [
  { id: "alpha", label: "Alphabetical", short: "A–Z" },
  { id: "recent", label: "Recently played", short: "Recent" },
  { id: "hours", label: "Hours played", short: "Hours" },
];

export function LibraryView({
  games,
  collections,
  recentAppIds,
}: {
  games: LibraryGridGame[];
  collections: Collection[];
  recentAppIds: number[];
}) {
  const { favorites } = useUserState();
  const [collectionId, setCollectionId] = useState(collections[0]?.id ?? "all");
  const [sort, setSort] = useState<SortKey>("alpha");
  const [filter, setFilter] = useState("");

  // Favorites is a live collection: X toggles it from anywhere.
  const liveCollections = useMemo(
    () => collections.map((c) => (c.id === "favorites" ? { ...c, appIds: games.filter((g) => favorites.has(g.appId)).map((g) => g.appId) } : c)),
    [collections, games, favorites],
  );
  const collection = liveCollections.find((c) => c.id === collectionId) ?? liveCollections[0];

  usePaging((dir) => {
    const i = liveCollections.findIndex((c) => c.id === collectionId);
    const next = liveCollections[(i + dir + liveCollections.length) % liveCollections.length];
    setCollectionId(next.id);
  });

  const byId = useMemo(() => new Map(games.map((g) => [g.appId, g])), [games]);
  const recent = recentAppIds.map((id) => byId.get(id)).filter((g): g is LibraryGridGame => !!g);

  const shown = useMemo(() => {
    const ids = new Set(collection?.appIds ?? []);
    const q = filter.trim().toLowerCase();
    const list = games.filter((g) => ids.has(g.appId) && (!q || g.name.toLowerCase().includes(q)));
    if (sort === "recent") list.sort((a, b) => (b.lastPlayed ?? "").localeCompare(a.lastPlayed ?? ""));
    else if (sort === "hours") list.sort((a, b) => b.playtimeMinutes - a.playtimeMinutes);
    return list;
  }, [games, collection, filter, sort]);

  const filterField = (extraClass: string) => (
    <label className={`search search--library ${extraClass}`}>
      <Search size={16} className="search__icon" aria-hidden="true" />
      <input
        className="search__input"
        type="search"
        placeholder="Search your library"
        aria-label="Search your library"
        autoComplete="off"
        spellCheck={false}
        data-search
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Escape" && filter) {
            e.preventDefault();
            setFilter("");
          }
        }}
      />
      {filter ? (
        <button type="button" className="search__clear" tabIndex={-1} aria-label="Clear" onClick={() => setFilter("")}>
          <X size={15} />
        </button>
      ) : null}
    </label>
  );

  const dynamic = liveCollections.filter((c) => c.kind === "dynamic");
  const user = liveCollections.filter((c) => c.kind !== "dynamic");
  const collButton = (c: Collection) => (
    <button key={c.id} type="button" className="coll" aria-pressed={c.id === collection?.id} onClick={() => setCollectionId(c.id)}>
      <span className="coll__name">{c.name}</span>
      <span className="coll__count">{c.appIds.length}</span>
    </button>
  );

  return (
    <div className="library">
      <aside className="lib-sidebar" aria-label="Collections">
        <div className="lib-sidebar__inner">
          {filterField("")}
          <div className="lib-sidebar__group">
            <div className="lib-sidebar__caption">Library</div>
            {dynamic.map(collButton)}
          </div>
          {user.length ? (
            <div className="lib-sidebar__group">
              <div className="lib-sidebar__caption">Collections</div>
              {user.map(collButton)}
            </div>
          ) : null}
        </div>
      </aside>

      <div className="lib-main">
        <PageTitle>Library</PageTitle>
        <div className="lib-toolbar">
          {filterField("lib-toolbar__search")}
          <div className="chips chips--collections" role="list" aria-label="Collections">
            {liveCollections.map((c) => (
              <button key={c.id} type="button" role="listitem" className="chip chip--neutral" aria-pressed={c.id === collection?.id} onClick={() => setCollectionId(c.id)}>
                {c.name}
                <span className="chip__count">{c.appIds.length}</span>
              </button>
            ))}
          </div>
        </div>

        {!filter && recent.length > 0 ? (
          <section className="section section--recent" aria-labelledby="recent-games">
            <SectionHeader id="recent-games" title="Recent Games" />
            <Shelf label="Recent games" className="shelf--recent">
              {recent.map((g, i) => (
                <RecentCard key={g.appId} game={g} first={i === 0} />
              ))}
            </Shelf>
          </section>
        ) : null}

        <section className="section" aria-labelledby="all-games">
          <SectionHeader id="all-games" title={collection?.name ?? "All Games"} count={shown.length}>
            <div className="segmented segmented--sort" role="group" aria-label="Sort by">
              {SORTS.map((s) => (
                <button key={s.id} type="button" aria-pressed={sort === s.id} onClick={() => setSort(s.id)}>
                  <span className="regular-only">{s.label}</span>
                  <span className="compact-only">{s.short}</span>
                </button>
              ))}
            </div>
          </SectionHeader>
          {shown.length === 0 ? (
            <p className="empty">No games match{filter ? ` “${filter}”` : ""}.</p>
          ) : (
            <div className="lib-grid">
              {shown.map((g) => (
                <GridCard key={g.appId} game={g} favorite={favorites.has(g.appId)} />
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}

function RecentCard({ game, first }: { game: LibraryGridGame; first: boolean }) {
  return (
    <Link
      href={`/library/game/${game.appId}/`}
      className={`recent-card card${first ? " recent-card--first" : ""}`}
      role="listitem"
      data-autofocus={first ? "" : undefined}
      data-x="favorite"
      data-id={game.appId}
      data-name={game.name}
    >
      <span className="recent-card__art">
        <Art className="art--fill" src={game.images.hero} fallbackSrc={game.images.capsule} label={game.images.logo ? undefined : game.name} />
        <span className="recent-card__scrim" />
        {game.images.logo ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img className="recent-card__logo" src={game.images.logo} alt={game.name} loading="lazy" decoding="async" />
        ) : (
          <span className="recent-card__title">{game.name}</span>
        )}
      </span>
      <span className="recent-card__meta">{game.lastPlayedLabel}</span>
    </Link>
  );
}

function GridCard({ game, favorite }: { game: LibraryGridGame; favorite: boolean }) {
  return (
    <Link
      href={`/library/game/${game.appId}/`}
      className={`lib-card card${game.installed ? "" : " lib-card--uninstalled"}`}
      data-x="favorite"
      data-id={game.appId}
      data-name={game.name}
      aria-label={`${game.name}${game.installed ? "" : " (not installed)"}`}
    >
      <Art className="art--portrait" src={game.images.portrait} fallbackSrc={game.images.header} label={game.name} />
      <span className="lib-card__badges">
        {game.updateAvailable ? <span className="lib-card__update" title="Update available" /> : null}
        {favorite ? (
          <span className="lib-card__star" title="Favorite">
            <Star size={12} fill="currentColor" />
          </span>
        ) : null}
      </span>
      {!game.installed ? (
        <span className="lib-card__dl" title="Not installed">
          <Download size={13} />
        </span>
      ) : null}
      <span className="lib-card__name">{game.name}</span>
    </Link>
  );
}
