import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { AppPage } from "@/components/store/AppPage";
import { libraryIds, storeAppIds, storePage } from "@/lib/data";

export const dynamicParams = false;

export function generateStaticParams() {
  return storeAppIds().map((id) => ({ appId: String(id) }));
}

type Props = { params: Promise<{ appId: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { appId } = await params;
  const model = storePage(Number(appId));
  const name = model ? (model.kind === "item" ? model.item.name : model.chart.name) : "Store";
  return { title: name };
}

export default async function StoreAppPage({ params }: Props) {
  const { appId } = await params;
  const model = storePage(Number(appId));
  if (!model) notFound();
  return <AppPage model={model} owned={libraryIds().has(Number(appId))} />;
}
