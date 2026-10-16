import { Monitor, Users } from "lucide-react";
import type { StorePageModel } from "@/lib/data";
import type { Images, Platforms, Price, ReviewSummary, Screenshot } from "@/lib/types";
import { Art } from "../ui/Art";
import { ControllerBadge, LiveDot, PlatformIcons, PriceBlock, ReviewLabel, SectionHeader, reviewTone } from "../ui/bits";
import { BackButton } from "../ui/BackButton";
import { PurchaseActions } from "./PurchaseActions";
import { ScreenshotViewer } from "./ScreenshotViewer";

interface View {
  appId: number;
  name: string;
  images: Images;
  price: Price | null;
  platforms: Platforms | null;
  controllerSupport: string | null;
  shortDescription: string | null;
  genres: string[];
  developers: string[];
  releaseDate: string | null;
  comingSoon: boolean;
  review: ReviewSummary | null;
  screenshots: Screenshot[];
  metacritic: number | null;
  discountEndsLabel: string | null;
  players: { current: string; peak: string } | null;
}

function toView(model: StorePageModel): View {
  const chart = model.chart;
  const players = chart ? { current: chart.currentPlayersLabel, peak: chart.peakTodayLabel } : null;
  if (model.kind === "item") return { ...model.item, players };
  const c = model.chart;
  return {
    appId: c.appId,
    name: c.name,
    images: c.images,
    price: c.price,
    platforms: null,
    controllerSupport: null,
    shortDescription: null,
    genres: [],
    developers: [],
    releaseDate: null,
    comingSoon: false,
    review: null,
    screenshots: [],
    metacritic: null,
    discountEndsLabel: null,
    players,
  };
}

export function AppPage({ model, owned }: { model: StorePageModel; owned: boolean }) {
  const v = toView(model);
  const backdrop = v.images.background ?? v.images.hero ?? v.images.capsule;
  const tone = reviewTone(v.review);
  return (
    <div className="page page--store app-page">
      <div className="app-backdrop" aria-hidden="true">
        <Art src={backdrop} eager />
      </div>
      <BackButton />
      <div className="page__inner page__inner--store app-page__inner">
        <div className="app-crumbs">
          All Games {v.genres[0] ? <>› {v.genres[0]} Games </> : null}› <span>{v.name}</span>
        </div>
        <h1 className="app-title">{v.name}</h1>

        <div className={`app-top${v.screenshots.length === 0 ? " app-top--no-media" : ""}`}>
          {v.screenshots.length > 0 ? (
            <div className="app-media">
              <ScreenshotViewer shots={v.screenshots} name={v.name} />
            </div>
          ) : (
            <div className="app-media">
              <Art className="art--capsule app-media__capsule" src={v.images.hero ?? v.images.capsule} fallbackSrc={v.images.capsule} label={v.name} eager />
            </div>
          )}
          <aside className="app-summary">
            <Art className="art--header app-summary__header" src={v.images.header} label={v.name} eager />
            {v.shortDescription ? <p className="app-summary__desc">{v.shortDescription}</p> : null}
            <dl className="app-facts">
              <div>
                <dt>All reviews</dt>
                <dd>
                  {v.review ? (
                    <>
                      <ReviewLabel review={v.review} /> <span className="muted">({v.review.totalLabel})</span>
                    </>
                  ) : (
                    <span className="muted">No user reviews</span>
                  )}
                </dd>
              </div>
              {v.releaseDate ? (
                <div>
                  <dt>Release date</dt>
                  <dd className="plain">{v.releaseDate}</dd>
                </div>
              ) : null}
              {v.developers.length ? (
                <div>
                  <dt>Developer</dt>
                  <dd>{v.developers.join(", ")}</dd>
                </div>
              ) : null}
              {v.players ? (
                <div>
                  <dt>Playing now</dt>
                  <dd className="plain">
                    <LiveDot /> {v.players.current}
                  </dd>
                </div>
              ) : null}
            </dl>
            {v.genres.length ? (
              <div className="app-tags">
                <span className="app-tags__caption">Popular user-defined tags for this product:</span>
                <span className="app-tags__list">
                  {v.genres.map((g) => (
                    <span key={g} className="tag">
                      {g}
                    </span>
                  ))}
                </span>
              </div>
            ) : null}
          </aside>
        </div>

        <div className="app-body">
          <div className="app-main">
            <div className="purchase">
              <div className="purchase__head">
                <h2 className="purchase__title">
                  {v.comingSoon ? "Wishlist " : !v.price ? "" : v.price.isFree ? "Play " : "Buy "}
                  {v.name}
                </h2>
                {v.platforms ? <PlatformIcons platforms={v.platforms} /> : null}
              </div>
              {v.discountEndsLabel ? <div className="purchase__offer">Special promotion! {v.discountEndsLabel}</div> : null}
              {v.comingSoon ? <div className="purchase__offer purchase__offer--soon">Planned release date: {v.releaseDate ?? "To be announced"}</div> : null}
              <div className="purchase__bar">
                {v.price ? <PriceBlock price={v.price} size="lg" /> : null}
                <PurchaseActions appId={v.appId} name={v.name} owned={owned} free={!!v.price?.isFree} comingSoon={v.comingSoon || !v.price} />
              </div>
            </div>

            {v.review ? (
              <section className="section app-reviews">
                <SectionHeader title="Customer reviews" />
                <div className="app-reviews__card" tabIndex={0} aria-label="Customer reviews">
                  <div className="app-reviews__score">
                    <span className={`app-reviews__pct review--${tone}`}>{v.review.percentPositive}%</span>
                    <span className="muted">positive</span>
                  </div>
                  <div className="app-reviews__detail">
                    <ReviewLabel review={v.review} />
                    <span className="muted">{v.review.totalLabel}</span>
                    <span className="app-reviews__bar">
                      <span className={`app-reviews__fill review-bg--${tone}`} style={{ width: `${v.review.percentPositive}%` }} />
                    </span>
                  </div>
                </div>
              </section>
            ) : null}

          </div>

          <aside className="app-side">
            {v.controllerSupport ? (
              <div className="app-side__card app-side__card--controller">
                <ControllerBadge support={v.controllerSupport} />
                <p className="muted">
                  {v.controllerSupport === "full"
                    ? "Play from start to finish with a gamepad."
                    : "Some parts may need a keyboard and mouse."}
                </p>
              </div>
            ) : null}
            {v.platforms ? (
              <div className="app-side__card">
                <h3 className="app-side__title">
                  <Monitor size={15} /> Platforms
                </h3>
                <ul className="app-side__list">
                  {v.platforms.windows ? <li>Windows</li> : null}
                  {v.platforms.mac ? <li>macOS</li> : null}
                  {v.platforms.linux ? <li>SteamOS + Linux</li> : null}
                </ul>
              </div>
            ) : null}
            {v.players ? (
              <div className="app-side__card">
                <h3 className="app-side__title">
                  <Users size={15} /> Players
                </h3>
                <p className="app-side__players">
                  <LiveDot /> {v.players.current}
                </p>
                <p className="muted">{v.players.peak}</p>
              </div>
            ) : null}
            {v.metacritic ? (
              <div className="app-side__card app-side__meta">
                <span className="metascore">{v.metacritic}</span>
                <span className="muted">Metascore</span>
              </div>
            ) : null}
          </aside>
        </div>
      </div>
    </div>
  );
}
