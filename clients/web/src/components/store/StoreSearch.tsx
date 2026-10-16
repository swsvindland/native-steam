"use client";

import Link from "next/link";
import { Search, X } from "lucide-react";
import { useEffect, useId, useMemo, useRef, useState } from "react";
import type { Price, Tag } from "@/lib/types";
import { Art } from "../ui/Art";
import { PriceBlock } from "../ui/bits";

export interface SearchEntry {
  appId: number;
  name: string;
  image: string;
  genres: string[];
  price: Price | null;
  releaseDate: string | null;
  comingSoon: boolean;
}

/** "Search the store" field with live suggestions, plus the popular-tag chips. */
export function StoreSearch({ index, tags }: { index: SearchEntry[]; tags: Tag[] }) {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const wrap = useRef<HTMLDivElement>(null);
  const bar = useRef<HTMLDivElement>(null);
  const listId = useId();

  // Close the suggestions when tapping / clicking anywhere else.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      if (!bar.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", onDown);
    return () => document.removeEventListener("pointerdown", onDown);
  }, [open]);

  const q = query.trim().toLowerCase();
  const results = useMemo(() => {
    if (!q) return [];
    return index
      .filter((e) => e.name.toLowerCase().includes(q) || e.genres.some((g) => g.toLowerCase() === q))
      .slice(0, 8);
  }, [index, q]);

  const show = open && q.length > 0;

  return (
    <div className="store-bar" ref={bar}>
      <div
        className="search"
        ref={wrap}
        onFocus={() => setOpen(true)}
        onBlur={(e) => {
          if (!wrap.current?.contains(e.relatedTarget as Node | null)) setOpen(false);
        }}
      >
        <Search size={17} className="search__icon" aria-hidden="true" />
        <input
          className="search__input"
          type="search"
          placeholder="Search the store"
          aria-label="Search the store"
          aria-controls={listId}
          aria-expanded={show}
          autoComplete="off"
          spellCheck={false}
          data-search
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Escape" && query) {
              e.preventDefault();
              setQuery("");
            }
          }}
        />
        {query ? (
          <button type="button" className="search__clear" tabIndex={-1} aria-label="Clear search" onClick={() => setQuery("")}>
            <X size={16} />
          </button>
        ) : null}
        {show ? (
          <div className="search-results" id={listId} role="listbox">
            {results.length === 0 ? (
              <div className="search-results__empty">No results for “{query.trim()}”</div>
            ) : (
              results.map((r) => (
                <Link key={r.appId} href={`/store/app/${r.appId}/`} className="search-result" role="option" aria-selected={false} data-search-result>
                  <Art className="art--small search-result__art" src={r.image} label={r.name} />
                  <span className="search-result__name">{r.name}</span>
                  <PriceBlock price={r.price} releaseDate={r.releaseDate} comingSoon={r.comingSoon} size="sm" />
                </Link>
              ))
            )}
          </div>
        ) : null}
      </div>
      <div className="chips" role="list" aria-label="Popular tags">
        {tags.map((t) => {
          const selected = q === t.name.toLowerCase();
          return (
            <button
              key={t.id}
              type="button"
              role="listitem"
              className="chip"
              aria-pressed={selected}
              onClick={() => {
                setQuery(selected ? "" : t.name);
                if (!selected) setOpen(true);
              }}
            >
              {t.name}
            </button>
          );
        })}
      </div>
    </div>
  );
}
