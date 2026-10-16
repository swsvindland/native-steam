import Link from "next/link";
import { Clock, Trophy } from "lucide-react";
import type { Friend, LibraryGame } from "@/lib/types";
import { Art } from "../ui/Art";
import { Avatar } from "../ui/Avatar";
import { BackButton } from "../ui/BackButton";
import { ControllerBadge, ProgressBar, SectionHeader } from "../ui/bits";
import { ShotButton } from "../ui/Lightbox";
import { GameActions } from "./GameActions";

export function GamePage({ game, friends, hasStorePage }: { game: LibraryGame; friends: Friend[]; hasStorePage: boolean }) {
  const ach = game.achievements;
  const shots = game.screenshots.map((s) => s.full);
  return (
    <div className="page page--library game-page">
      <BackButton />
      <div className="game-hero">
        <Art className="art--fill game-hero__art" src={game.images.hero} fallbackSrc={game.images.capsule} label={game.images.logo ? undefined : game.name} eager position="center top" />
        <span className="game-hero__scrim" />
        <div className="game-hero__content">
          {game.images.logo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img className="game-hero__logo" src={game.images.logo} alt={game.name} />
          ) : (
            <h1 className="game-hero__title">{game.name}</h1>
          )}
        </div>
      </div>

      <div className="game-actions">
        <div className="game-actions__inner">
          <GameActions
            appId={game.appId}
            name={game.name}
            installed={game.installed}
            sizeLabel={game.sizeLabel}
            updateAvailable={game.updateAvailable}
            hasStorePage={hasStorePage}
          />
          <dl className="game-stats">
            <div className="game-stat">
              <dt>Last played</dt>
              <dd>{game.lastPlayedLabel}</dd>
            </div>
            <div className="game-stat">
              <dt>Play time</dt>
              <dd>
                <Clock size={14} className="game-stat__icon" /> {game.playtimeLabel}
              </dd>
            </div>
            {ach ? (
              <div className="game-stat game-stat--ach">
                <dt>Achievements</dt>
                <dd>
                  <span>
                    <Trophy size={14} className="game-stat__icon" /> {ach.unlocked}/{ach.total}
                  </span>
                  <ProgressBar value={ach.fraction} />
                </dd>
              </div>
            ) : null}
          </dl>
        </div>
      </div>

      <div className="game-body">
        {game.images.logo ? <h1 className="sr-only">{game.name}</h1> : null}
        <div className="game-cols">
          <div className="game-col game-col--main">
            {ach && ach.highlighted.length ? (
              <section className="section" aria-labelledby="achievements">
                <SectionHeader id="achievements" title="Achievements">
                  <span className="section-aside">
                    {ach.unlocked} of {ach.total} unlocked · {Math.round(ach.fraction * 100)}%
                  </span>
                </SectionHeader>
                <div className="panel">
                  <ProgressBar value={ach.fraction} className="progress--wide" />
                  <div className="ach-strip" role="list">
                    {ach.highlighted.map((a) => (
                      <span
                        key={a.name}
                        role="listitem"
                        tabIndex={0}
                        className={`ach card${a.unlocked ? "" : " ach--locked"}`}
                        title={`${a.name}${a.unlockedLabel ? ` — ${a.unlockedLabel}` : " — Locked"}`}
                      >
                        <Art className="ach__icon" src={a.iconUrl} label={a.name.slice(0, 1)} />
                        <span className="ach__tip">
                          <strong>{a.name}</strong>
                          <span>{a.unlockedLabel ?? "Locked"}</span>
                        </span>
                      </span>
                    ))}
                  </div>
                </div>
              </section>
            ) : null}

            {friends.length ? (
              <section className="section compact-only" aria-labelledby="friends-play-c">
                <SectionHeader id="friends-play-c" title="Friends who play" count={friends.length} />
                <FriendsWhoPlay friends={friends} />
              </section>
            ) : null}

            {shots.length ? (
              <section className="section" aria-labelledby="screenshots">
                <SectionHeader id="screenshots" title="Screenshots" count={shots.length} />
                <div className="shot-grid">
                  {game.screenshots.map((s, i) => (
                    <ShotButton key={s.thumbnail} urls={shots} index={i} caption={game.name}>
                      <Art className="art--16x9" src={s.thumbnail} />
                    </ShotButton>
                  ))}
                </div>
              </section>
            ) : null}
          </div>

          <aside className="game-col game-col--side">
            {friends.length ? (
              <section className="section regular-only" aria-labelledby="friends-play">
                <SectionHeader id="friends-play" title="Friends who play" count={friends.length} />
                <FriendsWhoPlay friends={friends} />
              </section>
            ) : null}
            <section className="section" aria-labelledby="about">
              <SectionHeader id="about" title="About" />
              <div className="panel about" tabIndex={0} aria-label={`About ${game.name}`}>
                {game.shortDescription ? <p className="about__desc">{game.shortDescription}</p> : null}
                <dl className="about__facts">
                  {game.developers.length ? (
                    <div>
                      <dt>Developer</dt>
                      <dd>{game.developers.join(", ")}</dd>
                    </div>
                  ) : null}
                  {game.releaseDate ? (
                    <div>
                      <dt>Release date</dt>
                      <dd>{game.releaseDate}</dd>
                    </div>
                  ) : null}
                  {game.genres.length ? (
                    <div>
                      <dt>Genres</dt>
                      <dd>{game.genres.join(", ")}</dd>
                    </div>
                  ) : null}
                  <div>
                    <dt>Size on disk</dt>
                    <dd>{game.installed ? game.sizeLabel : `${game.sizeLabel} required`}</dd>
                  </div>
                </dl>
                <ControllerBadge support={game.controllerSupport} />
                {hasStorePage ? (
                  <Link href={`/store/app/${game.appId}/`} className="btn btn--secondary about__store">
                    Store page
                  </Link>
                ) : null}
              </div>
            </section>
          </aside>
        </div>
      </div>
    </div>
  );
}

function FriendsWhoPlay({ friends }: { friends: Friend[] }) {
  return (
    <ul className="friend-list friend-list--panel panel">
      {friends.map((f) => (
        <li key={f.steamId}>
          <span className={`friend-row card status--${f.status}`} tabIndex={0}>
            <Avatar src={f.avatarUrl} status={f.status} size={36} name={f.personaName} />
            <span className="friend-row__text">
              <span className="friend-row__name">{f.personaName}</span>
              <span className="friend-row__status">{f.statusLabel}</span>
            </span>
          </span>
        </li>
      ))}
    </ul>
  );
}
