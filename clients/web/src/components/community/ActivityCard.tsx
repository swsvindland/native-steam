"use client";

import { useRouter } from "next/navigation";
import { MessageSquare, ThumbsDown, ThumbsUp } from "lucide-react";
import type { ActivityItem } from "@/lib/types";
import { useUserState } from "../shell/UserState";
import { Art } from "../ui/Art";
import { Avatar } from "../ui/Avatar";

/** One FRIEND ACTIVITY card. The whole card is a single focus stop (A opens the game, X likes). */
export function ActivityCard({ item, status, href, first = false }: { item: ActivityItem; status: string; href: string | null; first?: boolean }) {
  const router = useRouter();
  const { liked, toggleLike } = useUserState();
  const isLiked = liked.has(item.id);

  return (
    <article
      className={`activity card${href ? " activity--link" : ""}`}
      tabIndex={0}
      data-autofocus={first ? "" : undefined}
      data-x="like"
      data-id={item.id}
      aria-label={`${item.friendName} ${item.headline} ${item.appName}, ${item.timeLabel}`}
      onClick={(e) => {
        if ((e.target as HTMLElement).closest("button")) return;
        if (href) router.push(href);
      }}
    >
      <header className="activity__head">
        <Avatar src={item.friendAvatarUrl} status={status} size={40} name={item.friendName} />
        <p className="activity__headline">
          <strong className={`activity__friend status-text--${status}`}>{item.friendName}</strong> {item.headline}{" "}
          <strong className="activity__app">{item.appName}</strong>
        </p>
        <time className="activity__time" dateTime={item.timestamp}>
          {item.timeLabel}
        </time>
      </header>

      <ActivityBody item={item} />

      <footer className="activity__foot">
        <button
          type="button"
          tabIndex={-1}
          className={`activity__btn${isLiked ? " is-on" : ""}`}
          aria-pressed={isLiked}
          onClick={() => toggleLike(item.id)}
        >
          <ThumbsUp size={15} fill={isLiked ? "currentColor" : "none"} /> {item.likes + (isLiked ? 1 : 0)}
        </button>
        <span className="activity__btn activity__btn--static">
          <MessageSquare size={15} /> {item.comments}
        </span>
      </footer>
    </article>
  );
}

function ActivityBody({ item }: { item: ActivityItem }) {
  switch (item.kind) {
    case "achievement":
      return item.achievement ? (
        <div className="activity__ach">
          <Art className="activity__ach-icon" src={item.achievement.iconUrl} label={item.achievement.name.slice(0, 1)} />
          <div>
            <div className="activity__ach-name">{item.achievement.name}</div>
            <div className="activity__ach-when">{item.achievement.unlockedLabel ?? "Unlocked"}</div>
          </div>
        </div>
      ) : null;
    case "screenshot":
      return (
        <div className="activity__shot">
          <Art className="art--16x9" src={item.imageUrl} fallbackSrc={item.appImages.capsule} label={item.appName} />
        </div>
      );
    case "review":
      return item.review ? (
        <div className={`activity__review${item.review.recommended ? " is-positive" : " is-negative"}`}>
          <div className="activity__verdict">
            <span className="activity__thumb">
              {item.review.recommended ? <ThumbsUp size={22} /> : <ThumbsDown size={22} />}
            </span>
            <div>
              <div className="activity__verdict-label">{item.review.recommended ? "Recommended" : "Not Recommended"}</div>
              <div className="activity__verdict-hours">{item.review.hoursLabel}</div>
            </div>
          </div>
          <blockquote className="activity__quote">{item.review.body}</blockquote>
        </div>
      ) : null;
    default:
      // nowPlaying / newGame: the game's header art with its name.
      return (
        <div className="activity__game">
          <Art className="art--header" src={item.appImages.header} label={item.appName} />
          <span className="activity__game-name">{item.appName}</span>
        </div>
      );
  }
}
