import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { GamePage } from "@/components/library/GamePage";
import { friendsById, getSnapshot, libraryGame, storeAppIds } from "@/lib/data";
import type { Friend } from "@/lib/types";

export const dynamicParams = false;

export function generateStaticParams() {
  return getSnapshot().library.games.map((g) => ({ appId: String(g.appId) }));
}

type Props = { params: Promise<{ appId: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { appId } = await params;
  return { title: libraryGame(Number(appId))?.name ?? "Library" };
}

export default async function LibraryGamePage({ params }: Props) {
  const { appId } = await params;
  const game = libraryGame(Number(appId));
  if (!game) notFound();
  const byId = friendsById();
  const friends = game.friendsPlaying.map((id) => byId.get(id)).filter((f): f is Friend => !!f);
  return <GamePage game={game} friends={friends} hasStorePage={storeAppIds().includes(game.appId)} />;
}
