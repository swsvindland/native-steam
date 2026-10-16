import type { Metadata } from "next";
import { CommunityPage } from "@/components/community/CommunityPage";

export const metadata: Metadata = { title: "Community" };

export default function Community() {
  return (
    <div className="page page--store">
      <div className="page__inner page__inner--community">
        <CommunityPage />
      </div>
    </div>
  );
}
