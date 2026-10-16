//! Display-string formatting shared by every generated `*Label` field.

use chrono::{DateTime, Datelike, Utc};

/// "142.3 hrs", "45 mins"
pub fn hours_label(minutes: u32) -> String {
    if minutes < 60 {
        format!("{minutes} mins")
    } else {
        let hours = minutes as f32 / 60.0;
        let text = format!("{hours:.1}");
        let text = text.strip_suffix(".0").unwrap_or(&text);
        format!("{} hrs", with_commas(text))
    }
}

fn with_commas(number: &str) -> String {
    let (int, frac) = number
        .split_once('.')
        .map_or((number, None), |(i, f)| (i, Some(f)));
    let grouped = steam_model::group_thousands(int.parse().unwrap_or(0));
    match frac {
        Some(f) => format!("{grouped}.{f}"),
        None => grouped,
    }
}

/// "12.4 GB", "512 MB"
pub fn size_label(gb: f32) -> String {
    if gb < 1.0 {
        format!("{} MB", (gb * 1024.0).round() as u32)
    } else {
        format!("{gb:.1} GB")
    }
}

/// "Oct 3" this year, otherwise "Oct 3, 2024".
pub fn short_date_relative_to(now: DateTime<Utc>, t: DateTime<Utc>) -> String {
    if t.year() == now.year() {
        t.format("%b %-d").to_string()
    } else {
        t.format("%b %-d, %Y").to_string()
    }
}

/// "Oct 3, 2026"
pub fn short_date(t: DateTime<Utc>) -> String {
    t.format("%b %-d, %Y").to_string()
}

/// "Today", "Yesterday", "Oct 3"
pub fn day_label(now: DateTime<Utc>, t: DateTime<Utc>) -> String {
    let days = (now.date_naive() - t.date_naive()).num_days();
    match days {
        0 => "Today".into(),
        1 => "Yesterday".into(),
        _ => short_date_relative_to(now, t),
    }
}

/// "just now", "12 mins ago", "3 hrs ago", "Yesterday", "4 days ago", "Oct 3"
pub fn relative(now: DateTime<Utc>, t: DateTime<Utc>) -> String {
    let minutes = (now - t).num_minutes().max(0);
    match minutes {
        0..=1 => "just now".into(),
        2..=59 => format!("{minutes} mins ago"),
        60..=119 => "1 hr ago".into(),
        120..=1439 => format!("{} hrs ago", minutes / 60),
        1440..=2879 => "Yesterday".into(),
        2880..=10079 => format!("{} days ago", minutes / 1440),
        _ => short_date_relative_to(now, t),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, TimeZone};

    #[test]
    fn hours() {
        assert_eq!(hours_label(8538), "142.3 hrs");
        assert_eq!(hours_label(120), "2 hrs");
        assert_eq!(hours_label(37092), "618.2 hrs");
        assert_eq!(hours_label(25), "25 mins");
        assert_eq!(hours_label(250_000), "4,166.7 hrs");
    }

    #[test]
    fn relative_times() {
        let now = Utc.with_ymd_and_hms(2026, 10, 16, 12, 0, 0).unwrap();
        assert_eq!(relative(now, now - Duration::minutes(12)), "12 mins ago");
        assert_eq!(relative(now, now - Duration::hours(3)), "3 hrs ago");
        assert_eq!(relative(now, now - Duration::hours(30)), "Yesterday");
        assert_eq!(relative(now, now - Duration::days(4)), "4 days ago");
        assert_eq!(relative(now, now - Duration::days(30)), "Sep 16");
        assert_eq!(day_label(now, now - Duration::days(400)), "Sep 11, 2025");
    }
}
