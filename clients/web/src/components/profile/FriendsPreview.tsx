"use client";

import { ChevronDown, ChevronUp } from "lucide-react";
import { useState } from "react";
import { Avatar } from "../ui/Avatar";
import { SectionHeader } from "../ui/bits";

/** FRIENDS: count + the first ~8 avatars, expanding to the full grouped list. */
export function FriendsPreview({
  count,
  avatars,
  children,
}: {
  count: number;
  avatars: { id: string; url: string; name: string; status: string }[];
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <SectionHeader id="friends-preview" title="Friends" count={count} />
      <div className="panel friends-preview">
        <div className="friends-preview__avatars">
          {avatars.map((a) => (
            <Avatar key={a.id} src={a.url} status={a.status} size={44} name={a.name} />
          ))}
        </div>
        <button type="button" className="btn btn--secondary friends-preview__toggle" aria-expanded={open} onClick={() => setOpen((v) => !v)}>
          {open ? "Hide friends" : `View all ${count} friends`}
          {open ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </button>
      </div>
      {open ? <div className="friends-preview__full">{children}</div> : null}
    </>
  );
}
