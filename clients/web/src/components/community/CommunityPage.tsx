import Link from "next/link";
import { friendsById, gameHref, getSnapshot, sortedFriends } from "@/lib/data";
import type { Friend } from "@/lib/types";
import { Art } from "../ui/Art";
import { Avatar } from "../ui/Avatar";
import { LiveDot, SectionHeader } from "../ui/bits";
import { ActivityCard } from "./ActivityCard";
import { CommunityView } from "./CommunityView";

export function CommunityPage() {
  const { community } = getSnapshot();
  const friends = friendsById();

  const activity = (
    <section aria-labelledby="friend-activity">
      <SectionHeader id="friend-activity" title="Friend Activity" />
      <div className="activity-feed">
        {community.activity.map((item, i) => (
          <ActivityCard key={item.id} item={item} first={i === 0} status={friends.get(item.friendId)?.status ?? "offline"} href={gameHref(item.appId)} />
        ))}
      </div>
    </section>
  );

  const news = (
    <section aria-labelledby="news">
      <SectionHeader id="news" title="News" />
      <div className="news-list">
        {community.news.map((n) => (
          <a key={n.id} href={n.url} target="_blank" rel="noopener noreferrer" className="news card">
            <Art className="art--header news__art" src={n.imageUrl} fallbackSrc={n.appImages.header} label={n.appName} />
            <span className="news__body">
              <span className="news__meta">
                <span className="news__app">{n.appName}</span> · {n.feedLabel} · {n.dateLabel}
              </span>
              <span className="news__title">{n.title}</span>
              <span className="news__excerpt">{n.excerpt}</span>
            </span>
          </a>
        ))}
      </div>
    </section>
  );

  const hubs = (
    <section aria-labelledby="hubs">
      <SectionHeader id="hubs" title="Popular Hubs" />
      <ol className="hub-list">
        {community.hubs.map((h, i) => {
          const href = gameHref(h.appId);
          const inner = (
            <>
              <span className="hub__rank">{i + 1}</span>
              <Art className="art--header hub__art" src={h.images.header} label={h.name} />
              <span className="hub__text">
                <span className="hub__name">{h.name}</span>
                <span className="hub__players">
                  <LiveDot /> {h.currentPlayersLabel}
                </span>
              </span>
            </>
          );
          return (
            <li key={h.appId}>
              {href ? (
                <Link href={href} className="hub card">
                  {inner}
                </Link>
              ) : (
                <span className="hub card" tabIndex={0}>
                  {inner}
                </span>
              )}
            </li>
          );
        })}
      </ol>
    </section>
  );

  const friendList = <FriendsPanel friends={sortedFriends()} />;

  return <CommunityView activity={activity} news={news} hubs={hubs} friends={friendList} />;
}

export function FriendsPanel({ friends, title = "Friends" }: { friends: Friend[]; title?: string }) {
  const groups: { id: string; label: string; items: Friend[] }[] = [
    { id: "inGame", label: "In-Game", items: friends.filter((f) => f.status === "inGame") },
    { id: "online", label: "Online", items: friends.filter((f) => f.status === "online" || f.status === "away") },
    { id: "offline", label: "Offline", items: friends.filter((f) => f.status !== "inGame" && f.status !== "online" && f.status !== "away") },
  ];
  return (
    <section aria-labelledby="friends-title">
      <SectionHeader id="friends-title" title={title} count={friends.length} />
      <div className="panel friends-panel">
        {groups
          .filter((g) => g.items.length)
          .map((g) => (
            <div key={g.id} className="friends-group">
              <div className={`friends-group__label status-text--${g.id}`}>
                {g.label} <span className="muted">({g.items.length})</span>
              </div>
              <ul className="friend-list">
                {g.items.map((f) => {
                  const href = f.game ? gameHref(f.game.appId) : null;
                  const body = (
                    <>
                      <Avatar src={f.avatarUrl} status={f.status} size={36} name={f.personaName} />
                      <span className="friend-row__text">
                        <span className="friend-row__name">{f.personaName}</span>
                        <span className="friend-row__status">{f.statusLabel}</span>
                      </span>
                    </>
                  );
                  return (
                    <li key={f.steamId}>
                      {href ? (
                        <Link href={href} className={`friend-row card status--${f.status}`}>
                          {body}
                        </Link>
                      ) : (
                        <span className={`friend-row card status--${f.status}`} tabIndex={0}>
                          {body}
                        </span>
                      )}
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
      </div>
    </section>
  );
}
