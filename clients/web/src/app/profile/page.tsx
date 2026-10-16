import type { Metadata } from "next";
import { ProfilePage } from "@/components/profile/ProfilePage";
import { getSnapshot } from "@/lib/data";

export function generateMetadata(): Metadata {
  return { title: getSnapshot().user.personaName };
}

export default function Profile() {
  return <ProfilePage />;
}
