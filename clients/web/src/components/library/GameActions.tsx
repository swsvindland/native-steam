"use client";

import Link from "next/link";
import { Download, Info, Play, Settings, Star } from "lucide-react";
import { useUserState } from "../shell/UserState";

/** PLAY / INSTALL + favorite, settings, store page. All visual only. */
export function GameActions({
  appId,
  name,
  installed,
  sizeLabel,
  updateAvailable,
  hasStorePage,
}: {
  appId: number;
  name: string;
  installed: boolean;
  sizeLabel: string;
  updateAvailable: boolean;
  hasStorePage: boolean;
}) {
  const { favorites, toggleFavorite, showToast } = useUserState();
  const fav = favorites.has(appId);
  return (
    <div className="game-actions__buttons">
      {installed ? (
        <button
          type="button"
          className="btn btn--play btn--xl"
          data-autofocus
          data-x="favorite"
          data-id={appId}
          data-name={name}
          onClick={() => showToast(`Launching ${name}… (demo only)`)}
        >
          <Play size={22} fill="currentColor" /> Play
        </button>
      ) : (
        <button
          type="button"
          className="btn btn--install btn--xl"
          data-autofocus
          data-x="favorite"
          data-id={appId}
          data-name={name}
          onClick={() => showToast(`Installing ${name} · ${sizeLabel} (demo only)`)}
        >
          <Download size={22} /> Install
          <span className="btn__sub">{sizeLabel}</span>
        </button>
      )}
      {updateAvailable && installed ? <span className="game-actions__update">Update available</span> : null}
      <span className="game-actions__secondary">
        <button
          type="button"
          className={`iconbtn iconbtn--round${fav ? " is-on" : ""}`}
          aria-pressed={fav}
          aria-label={fav ? "Remove from Favorites" : "Add to Favorites"}
          title={fav ? "Remove from Favorites" : "Add to Favorites"}
          onClick={() => toggleFavorite(appId, name)}
        >
          <Star size={19} fill={fav ? "currentColor" : "none"} />
        </button>
        <button type="button" className="iconbtn iconbtn--round" aria-label="Properties" title="Properties" onClick={() => showToast("Properties · demo only")}>
          <Settings size={19} />
        </button>
        {hasStorePage ? (
          <Link href={`/store/app/${appId}/`} className="iconbtn iconbtn--round" aria-label="Store page" title="Store page">
            <Info size={19} />
          </Link>
        ) : (
          <button type="button" className="iconbtn iconbtn--round" aria-label="Game info" title="Game info" onClick={() => showToast(`${name} · info`)}>
            <Info size={19} />
          </button>
        )}
      </span>
    </div>
  );
}
