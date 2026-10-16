"use client";

import { useState } from "react";
import { usePaging } from "../shell/NavContext";
import { PageTitle } from "../ui/bits";

type Segment = "activity" | "news" | "hubs";
const SEGMENTS: { id: Segment; label: string }[] = [
  { id: "activity", label: "Activity" },
  { id: "news", label: "News" },
  { id: "hubs", label: "Hubs" },
];

/**
 * Compact: a segmented control shows one section at a time.
 * Regular: Activity is the main column with News beside it; Hubs + Friends
 * sit in a right rail from 1100 px (below that they stack under News).
 */
export function CommunityView({
  activity,
  news,
  hubs,
  friends,
}: {
  activity: React.ReactNode;
  news: React.ReactNode;
  hubs: React.ReactNode;
  friends: React.ReactNode;
}) {
  const [seg, setSeg] = useState<Segment>("activity");
  usePaging((dir) => {
    const i = SEGMENTS.findIndex((s) => s.id === seg);
    setSeg(SEGMENTS[(i + dir + SEGMENTS.length) % SEGMENTS.length].id);
  });

  return (
    <div className="community" data-seg={seg}>
      <PageTitle>Community</PageTitle>
      <div className="segmented segmented--full compact-only" role="tablist" aria-label="Community sections">
        {SEGMENTS.map((s) => (
          <button key={s.id} type="button" role="tab" aria-selected={seg === s.id} aria-pressed={seg === s.id} onClick={() => setSeg(s.id)}>
            {s.label}
          </button>
        ))}
      </div>
      <div className="community__grid">
        <div className="community__col community__col--activity" data-active={seg === "activity"}>
          {activity}
        </div>
        <div className="community__col community__col--news" data-active={seg === "news"}>
          {news}
        </div>
        <aside className="community__rail">
          <div className="community__hubs" data-active={seg === "hubs"}>
            {hubs}
          </div>
          <div className="community__friends" id="friends">
            {friends}
          </div>
        </aside>
      </div>
    </div>
  );
}
