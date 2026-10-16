import Link from "next/link";
import { Award, CalendarClock, Gamepad2, Layers, MapPin, Pencil, Tag, Trophy, Users } from "lucide-react";
import { gameHref, getSnapshot, libraryGame, sortedFriends } from "@/lib/data";
import type { Badge } from "@/lib/types";
import { Art } from "../ui/Art";
import { LevelRing, ProgressBar, SectionHeader } from "../ui/bits";
import { ShotButton } from "../ui/Lightbox";
import { FriendsPanel } from "../community/CommunityPage";
import { FriendsPreview } from "./FriendsPreview";

const BADGE_ICONS: Record<string, React.ComponentType<{ size?: number; strokeWidth?: number }>> = {
  years: CalendarClock,
  sale: Tag,
  collector: Layers,
  community: Users,
  awards: Award,
  deck: Gamepad2,
  trophy: Trophy,
};

export function ProfilePage() {
  const { user } = getSnapshot();
  const fav = libraryGame(user.favoriteGame.appId);
  const friends = sortedFriends();
  const s = user.stats;
  const stats: [string, string][] = [
    [String(s.gamesOwned), "Games"],
    [s.achievements.toLocaleString("en-US"), "Achievements"],
    [String(s.perfectGames), "Perfect games"],
    [s.hoursLabel, "Played"],
    [String(s.friends), "Friends"],
    [s.screenshots.toLocaleString("en-US"), "Screenshots"],
    [String(s.reviews), "Reviews"],
  ];
  const shotUrls = user.screenshots.map((x) => x.url);

  return (
    <div className="page page--library profile">
      <section className="profile-banner" aria-label="Profile">
        <div className="profile-banner__bg" aria-hidden="true">
          <Art src={user.backgroundUrl} eager position="center 30%" />
        </div>
        <div className="profile-banner__inner">
          <span className="profile-avatar">
            <Art src={user.avatarUrl} label={user.personaName.slice(0, 1)} eager />
          </span>
          <div className="profile-id">
            <h1 className="profile-id__name">{user.personaName}</h1>
            <p className="profile-id__sub">
              {user.realName} <span className="dot-sep">·</span> <MapPin size={13} /> {user.country}
            </p>
            <p className="profile-id__online">Currently Online</p>
          </div>
          <div className="profile-level">
            <div className="profile-level__row">
              <span className="profile-level__label">Level</span>
              <LevelRing level={user.level} color={user.levelColor} size="lg" />
            </div>
            <ProgressBar value={user.xpFraction} className="progress--xp" />
            <span className="profile-level__xp">{user.xpToNextLabel}</span>
            <button type="button" className="btn btn--secondary profile-edit" data-autofocus>
              <Pencil size={14} /> Edit Profile
            </button>
          </div>
        </div>
      </section>

      <div className="page__inner page__inner--profile">
        <div className="profile-summary">
          <p className="profile-summary__text">{user.summary}</p>
          <p className="profile-summary__since">
            {user.memberSinceLabel} <span className="dot-sep">·</span> {user.yearsLabel}
          </p>
        </div>

        <dl className="profile-stats">
          {stats.map(([value, label]) => (
            <div key={label} className="profile-stat">
              <dd>{value}</dd>
              <dt>{label}</dt>
            </div>
          ))}
        </dl>

        <div className="profile-cols">
          <div className="profile-col profile-col--main">
            <Badges badges={user.badges} total={s.badges} id="badges-c" className="compact-only" />

            {fav ? (
              <section className="section" aria-labelledby="favorite-game">
                <SectionHeader id="favorite-game" title="Favorite Game" />
                <Link href={`/library/game/${fav.appId}/`} className="fav-game card">
                  <span className="fav-game__art">
                    <Art className="art--fill" src={fav.images.hero} fallbackSrc={fav.images.capsule} label={fav.images.logo ? undefined : fav.name} />
                    <span className="fav-game__scrim" />
                    {fav.images.logo ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img className="fav-game__logo" src={fav.images.logo} alt={fav.name} loading="lazy" />
                    ) : (
                      <span className="fav-game__title">{fav.name}</span>
                    )}
                  </span>
                  <span className="fav-game__stats">
                    <span className="fav-game__stat">
                      <strong>{fav.playtimeLabel}</strong>
                    </span>
                    {fav.achievements ? (
                      <span className="fav-game__stat fav-game__stat--ach">
                        <span>
                          <Trophy size={14} /> {fav.achievements.unlocked} of {fav.achievements.total} achievements
                        </span>
                        <ProgressBar value={fav.achievements.fraction} />
                      </span>
                    ) : null}
                  </span>
                </Link>
              </section>
            ) : null}

            <section className="section" aria-labelledby="recent-activity">
              <SectionHeader id="recent-activity" title="Recent Activity" />
              <div className="recent-rows">
                {user.recentGames.map((g) => (
                  <Link key={g.appId} href={gameHref(g.appId) ?? `/library/`} className="recent-row card">
                    <Art className="art--header recent-row__art" src={g.images.header} label={g.name} />
                    <span className="recent-row__body">
                      <span className="recent-row__top">
                        <span className="recent-row__name">{g.name}</span>
                        <span className="recent-row__total">{g.totalLabel}</span>
                      </span>
                      <span className="recent-row__sub">
                        {g.twoWeeksLabel} <span className="dot-sep">·</span> {g.lastPlayedLabel}
                      </span>
                      {g.achievements ? (
                        <span className="recent-row__ach">
                          <span className="recent-row__ach-label">
                            Achievement progress <strong>{g.achievements.unlocked}</strong> of {g.achievements.total}
                          </span>
                          <ProgressBar value={g.achievements.fraction} />
                        </span>
                      ) : null}
                    </span>
                  </Link>
                ))}
              </div>
            </section>

            <section className="section" aria-labelledby="rare-ach">
              <SectionHeader id="rare-ach" title="Rare Achievement Showcase" />
              <div className="rare-grid panel">
                {user.rareAchievements.map((r) => (
                  <Link key={`${r.appId}-${r.achievement.name}`} href={gameHref(r.appId) ?? "/library/"} className="rare card" title={r.achievement.unlockedLabel ?? undefined}>
                    <Art className="rare__icon" src={r.achievement.iconUrl} label={r.achievement.name.slice(0, 1)} />
                    <span className="rare__name">{r.achievement.name}</span>
                    <span className="rare__game">{r.appName}</span>
                  </Link>
                ))}
              </div>
            </section>

            <section className="section" aria-labelledby="shots">
              <SectionHeader id="shots" title="Screenshot Showcase" count={s.screenshots} />
              <div className="shot-showcase">
                {user.screenshots.slice(0, 4).map((sh, i) => (
                  <ShotButton key={sh.url} urls={shotUrls} index={i} caption={sh.appName} className={i === 0 ? "shot--large" : ""}>
                    <Art className="art--fill" src={sh.url} label={sh.appName} />
                    <span className="shot__caption">{sh.appName}</span>
                  </ShotButton>
                ))}
              </div>
            </section>
          </div>

          <aside className="profile-col profile-col--side">
            <Badges badges={user.badges} total={s.badges} id="badges-r" className="regular-only" />
            <section className="section" aria-labelledby="friends-preview">
              <FriendsPreview count={friends.length} avatars={friends.slice(0, 8).map((f) => ({ id: f.steamId, url: f.avatarUrl, name: f.personaName, status: f.status }))}>
                <FriendsPanel friends={friends} title="All friends" />
              </FriendsPreview>
            </section>
          </aside>
        </div>
      </div>
    </div>
  );
}


function Badges({ badges, total, id, className }: { badges: Badge[]; total: number; id: string; className: string }) {
  return (
    <section className={`section ${className}`} aria-labelledby={id}>
      <SectionHeader id={id} title="Badges" count={total} />
      <div className="badges panel">
        {badges.map((b) => {
          const Icon = BADGE_ICONS[b.icon] ?? Award;
          return (
            <span key={b.name} className="badge card" tabIndex={0} title={`${b.name} — ${b.description}`}>
              <span className="badge__medal" style={{ ["--badge" as string]: b.color }}>
                <Icon size={26} strokeWidth={1.8} />
                <span className="badge__level">{b.level}</span>
              </span>
              <span className="badge__name">{b.name}</span>
              <span className="badge__xp">{b.xp} XP</span>
            </span>
          );
        })}
      </div>
    </section>
  );
}
