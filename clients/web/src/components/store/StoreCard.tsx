import Link from "next/link";
import { CalendarDays } from "lucide-react";
import type { StoreItem } from "@/lib/types";
import { Art } from "../ui/Art";
import { PlatformIcons, PriceBlock, ReviewLabel, ToneDot } from "../ui/bits";
import { WishMark } from "./WishMark";

export function storeHref(appId: number): string {
  return `/store/app/${appId}/`;
}

/** Shelf card: header art, name, a meta line and the price block. */
export function StoreCard({
  item,
  meta,
  variant = "default",
}: {
  item: StoreItem;
  meta?: React.ReactNode;
  variant?: "default" | "special" | "upcoming";
}) {
  return (
    <Link
      href={storeHref(item.appId)}
      className={`store-card card store-card--${variant}`}
      role="listitem"
      data-x="wishlist"
      data-id={item.appId}
      data-name={item.name}
    >
      <Art className="art--header" src={item.images.header} label={item.name} />
      <WishMark appId={item.appId} />
      <span className="store-card__body">
        <span className="store-card__name">{item.name}</span>
        {meta ? <span className="store-card__meta">{meta}</span> : null}
        <span className="store-card__foot">
          {variant === "upcoming" ? (
            <span className="store-card__date">
              <CalendarDays size={13} /> {item.releaseDate ?? "To be announced"}
            </span>
          ) : item.review ? (
            <span className="store-card__review">
              <ToneDot review={item.review} />
              <ReviewLabel review={item.review} />
            </span>
          ) : (
            <span />
          )}
          {variant === "upcoming" && !item.price ? null : (
            <PriceBlock price={item.price} releaseDate={item.releaseDate} comingSoon={item.comingSoon} size="sm" />
          )}
        </span>
      </span>
    </Link>
  );
}

/** Two-column list row used by TOP SELLERS on regular widths. */
export function StoreRow({ item, rank }: { item: StoreItem; rank?: number }) {
  return (
    <Link
      href={storeHref(item.appId)}
      className="store-row card"
      data-x="wishlist"
      data-id={item.appId}
      data-name={item.name}
    >
      {rank !== undefined ? <span className="store-row__rank">{rank}</span> : null}
      <Art className="art--small store-row__art" src={item.images.smallCapsule} label={item.name} />
      <span className="store-row__body">
        <span className="store-row__name">{item.name}</span>
        <span className="store-row__meta">
          <PlatformIcons platforms={item.platforms} />
          <span className="store-row__genres">{item.genres.slice(0, 3).join(", ")}</span>
        </span>
      </span>
      <span className="store-row__review">
        <ToneDot review={item.review} />
      </span>
      <WishMark appId={item.appId} inline />
      <PriceBlock price={item.price} releaseDate={item.releaseDate} comingSoon={item.comingSoon} />
    </Link>
  );
}
