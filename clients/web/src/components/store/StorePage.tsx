import Link from "next/link";
import { getSnapshot, storeItems } from "@/lib/data";
import { Art } from "../ui/Art";
import { LiveDot, PageTitle, PriceBlock, SectionHeader } from "../ui/bits";
import { Shelf } from "../ui/Shelf";
import { HeroCarousel } from "./HeroCarousel";
import { StoreCard, StoreRow, storeHref } from "./StoreCard";
import { type SearchEntry, StoreSearch } from "./StoreSearch";

export function StorePage() {
  const { store } = getSnapshot();
  const index: SearchEntry[] = [...storeItems().values()].map((i) => ({
    appId: i.appId,
    name: i.name,
    image: i.images.smallCapsule,
    genres: i.genres,
    price: i.price,
    releaseDate: i.releaseDate,
    comingSoon: i.comingSoon,
  }));
  for (const c of store.mostPlayed) {
    if (!index.some((e) => e.appId === c.appId)) {
      index.push({ appId: c.appId, name: c.name, image: c.images.smallCapsule, genres: [], price: c.price, releaseDate: null, comingSoon: false });
    }
  }

  return (
    <div className="page page--store">
      <div className="page__inner page__inner--store">
        <PageTitle>Store</PageTitle>
        <StoreSearch index={index} tags={store.popularTags} />

        <section className="section section--hero" aria-labelledby="featured">
          <SectionHeader id="featured" title="Featured & Recommended" />
          <HeroCarousel items={store.featured} />
        </section>

        <section className="section" aria-labelledby="specials">
          <SectionHeader id="specials" title="Special Offers" />
          <Shelf label="Special offers" className="shelf--specials">
            {store.specials.map((item) => (
              <StoreCard key={item.appId} item={item} variant="special" meta={item.discountEndsLabel ?? item.genres.join(", ")} />
            ))}
          </Shelf>
        </section>

        <section className="section" aria-labelledby="top-sellers">
          <SectionHeader id="top-sellers" title="Top Sellers" />
          <div className="ts-list regular-only">
            {store.topSellers.map((item, i) => (
              <StoreRow key={item.appId} item={item} rank={i + 1} />
            ))}
          </div>
          <div className="compact-only">
            <Shelf label="Top sellers">
              {store.topSellers.map((item) => (
                <StoreCard key={item.appId} item={item} meta={item.genres.slice(0, 3).join(", ")} />
              ))}
            </Shelf>
          </div>
        </section>

        <section className="section" aria-labelledby="new-trending">
          <SectionHeader id="new-trending" title="New & Trending" />
          <Shelf label="New and trending">
            {store.newReleases.map((item) => (
              <StoreCard key={item.appId} item={item} meta={item.genres.slice(0, 3).join(", ") || item.releaseDate} />
            ))}
          </Shelf>
        </section>

        <section className="section" aria-labelledby="most-played">
          <SectionHeader id="most-played" title="Most Played" />
          <div className="chart-head regular-only" aria-hidden="true">
            <span>Rank</span>
            <span />
            <span>Game</span>
            <span>Current players</span>
            <span>Peak today</span>
            <span className="chart-head__price">Price</span>
          </div>
          <ol className="chart">
            {store.mostPlayed.map((c) => (
              <li key={c.appId}>
                <Link href={storeHref(c.appId)} className="chart-row card" data-x="wishlist" data-id={c.appId} data-name={c.name}>
                  <span className="chart-row__rank">#{c.rank}</span>
                  <Art className="art--header chart-row__art" src={c.images.header} label={c.name} />
                  <span className="chart-row__name">
                    <span className="chart-row__title">{c.name}</span>
                    <span className="chart-row__sub compact-only">
                      <LiveDot /> {c.currentPlayersLabel}
                    </span>
                  </span>
                  <span className="chart-row__players regular-only">
                    <LiveDot /> {c.currentPlayersLabel}
                  </span>
                  <span className="chart-row__peak regular-only">{c.peakTodayLabel}</span>
                  <span className="chart-row__price">{c.price ? <PriceBlock price={c.price} size="sm" /> : null}</span>
                </Link>
              </li>
            ))}
          </ol>
        </section>

        <section className="section" aria-labelledby="upcoming">
          <SectionHeader id="upcoming" title="Popular Upcoming" />
          <Shelf label="Popular upcoming">
            {store.comingSoon.map((item) => (
              <StoreCard key={item.appId} item={item} variant="upcoming" meta={item.genres.slice(0, 3).join(", ") || item.developers[0]} />
            ))}
          </Shelf>
        </section>
      </div>
    </div>
  );
}
