// TypeScript mirror of core/crates/steam-model/src/lib.rs (serialized camelCase).
// `Option<T>` in Rust maps to `T | null` here.

export interface Snapshot {
  schemaVersion: number;
  generatedAt: string;
  region: string;
  user: UserProfile;
  store: Store;
  library: Library;
  community: Community;
  friends: Friend[];
}

export interface Images {
  header: string;
  capsule: string;
  smallCapsule: string;
  portrait: string | null;
  hero: string | null;
  logo: string | null;
  background: string | null;
}

export interface Platforms {
  windows: boolean;
  mac: boolean;
  linux: boolean;
}

export interface Price {
  currency: string;
  initial: number;
  finalPrice: number;
  discountPercent: number;
  initialLabel: string;
  finalLabel: string;
  discountLabel: string | null;
  isFree: boolean;
}

export interface Screenshot {
  thumbnail: string;
  full: string;
}

export type ReviewTone = "positive" | "mixed" | "negative" | (string & {});

export interface ReviewSummary {
  label: string;
  percentPositive: number;
  total: number;
  totalLabel: string;
  tone: ReviewTone;
}

export interface Achievement {
  name: string;
  iconUrl: string;
  unlocked: boolean;
  unlockedLabel: string | null;
}

export interface StoreItem {
  appId: number;
  name: string;
  images: Images;
  price: Price | null;
  platforms: Platforms;
  /** "full" | "partial" | null */
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
}

export interface ChartEntry {
  rank: number;
  appId: number;
  name: string;
  images: Images;
  currentPlayers: number;
  currentPlayersLabel: string;
  peakToday: number;
  peakTodayLabel: string;
  price: Price | null;
}

export interface Tag {
  id: number;
  name: string;
}

export interface Store {
  featured: StoreItem[];
  specials: StoreItem[];
  topSellers: StoreItem[];
  newReleases: StoreItem[];
  comingSoon: StoreItem[];
  mostPlayed: ChartEntry[];
  popularTags: Tag[];
}

export interface AchievementProgress {
  unlocked: number;
  total: number;
  fraction: number;
  highlighted: Achievement[];
}

export interface LibraryGame {
  appId: number;
  name: string;
  images: Images;
  playtimeMinutes: number;
  playtimeLabel: string;
  playtimeTwoWeeksMinutes: number;
  playtimeTwoWeeksLabel: string | null;
  lastPlayed: string | null;
  lastPlayedLabel: string;
  installed: boolean;
  sizeOnDiskBytes: number;
  sizeLabel: string;
  favorite: boolean;
  updateAvailable: boolean;
  achievements: AchievementProgress | null;
  controllerSupport: string | null;
  genres: string[];
  developers: string[];
  shortDescription: string | null;
  releaseDate: string | null;
  screenshots: Screenshot[];
  friendsPlaying: string[];
}

export interface Collection {
  id: string;
  name: string;
  /** "dynamic" | "user" */
  kind: string;
  appIds: number[];
}

export interface Library {
  games: LibraryGame[];
  collections: Collection[];
  recentAppIds: number[];
}

export interface ActivityReview {
  recommended: boolean;
  body: string;
  hoursLabel: string;
}

export type ActivityKind = "achievement" | "screenshot" | "review" | "nowPlaying" | "newGame" | (string & {});

export interface ActivityItem {
  id: string;
  kind: ActivityKind;
  friendId: string;
  friendName: string;
  friendAvatarUrl: string;
  appId: number;
  appName: string;
  appImages: Images;
  timestamp: string;
  timeLabel: string;
  headline: string;
  achievement: Achievement | null;
  imageUrl: string | null;
  review: ActivityReview | null;
  likes: number;
  comments: number;
}

export interface NewsItem {
  id: string;
  appId: number;
  appName: string;
  appImages: Images;
  title: string;
  author: string | null;
  url: string;
  date: string;
  dateLabel: string;
  excerpt: string;
  imageUrl: string | null;
  feedLabel: string;
}

export interface Hub {
  appId: number;
  name: string;
  images: Images;
  currentPlayers: number;
  currentPlayersLabel: string;
  rank: number;
}

export interface Community {
  activity: ActivityItem[];
  news: NewsItem[];
  hubs: Hub[];
}

export interface GameRef {
  appId: number;
  name: string;
}

export type FriendStatus = "inGame" | "online" | "away" | "offline" | (string & {});

export interface Friend {
  steamId: string;
  personaName: string;
  avatarUrl: string;
  level: number;
  levelColor: string;
  status: FriendStatus;
  statusLabel: string;
  game: GameRef | null;
}

export interface Badge {
  name: string;
  description: string;
  level: number;
  xp: number;
  color: string;
  /** "years" | "sale" | "collector" | "community" | "awards" | "deck" | "trophy" */
  icon: string;
}

export interface ProfileStats {
  gamesOwned: number;
  achievements: number;
  perfectGames: number;
  friends: number;
  screenshots: number;
  reviews: number;
  badges: number;
  hoursLabel: string;
}

export interface RecentGame {
  appId: number;
  name: string;
  images: Images;
  twoWeeksLabel: string;
  totalLabel: string;
  lastPlayedLabel: string;
  achievements: AchievementProgress | null;
}

export interface ShowcaseAchievement {
  appId: number;
  appName: string;
  achievement: Achievement;
}

export interface ShowcaseScreenshot {
  appId: number;
  appName: string;
  url: string;
}

export interface UserProfile {
  steamId: string;
  personaName: string;
  realName: string;
  avatarUrl: string;
  backgroundUrl: string;
  country: string;
  level: number;
  levelColor: string;
  xp: number;
  xpToNextLabel: string;
  xpFraction: number;
  status: string;
  summary: string;
  memberSinceLabel: string;
  yearsLabel: string;
  stats: ProfileStats;
  badges: Badge[];
  favoriteGame: GameRef;
  recentGames: RecentGame[];
  rareAchievements: ShowcaseAchievement[];
  screenshots: ShowcaseScreenshot[];
}
