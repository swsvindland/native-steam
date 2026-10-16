import type { Metadata } from "next";
import { StorePage } from "@/components/store/StorePage";

export const metadata: Metadata = { title: "Store" };

export default function Store() {
  return <StorePage />;
}
