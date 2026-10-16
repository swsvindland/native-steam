//! Helpers for turning Steam news bodies (BBCode, sometimes HTML) into plain
//! text excerpts and a lead image.

use regex::Regex;
use std::sync::OnceLock;

const CLAN_IMAGE_BASE: &str = "https://clan.akamai.steamstatic.com/images";

fn re(cell: &'static OnceLock<Regex>, pattern: &str) -> &'static Regex {
    cell.get_or_init(|| Regex::new(pattern).expect("valid regex"))
}

/// First image referenced by a news body, resolved to an absolute URL.
pub fn first_image(contents: &str) -> Option<String> {
    static CLAN: OnceLock<Regex> = OnceLock::new();
    static HTML: OnceLock<Regex> = OnceLock::new();
    static BB: OnceLock<Regex> = OnceLock::new();

    let clan = re(
        &CLAN,
        r#"\{STEAM_CLAN_IMAGE\}(/[^\s\[\]"'<>]+\.(?:png|jpe?g|gif|webp))"#,
    );
    if let Some(c) = clan.captures(contents) {
        return Some(format!("{CLAN_IMAGE_BASE}{}", &c[1]));
    }
    let html = re(&HTML, r#"<img[^>]+src=["'](https?://[^"']+)["']"#);
    if let Some(c) = html.captures(contents) {
        return Some(c[1].to_string());
    }
    let bb = re(
        &BB,
        r#"\[img(?:\s+src=["']?)?\]?(https?://[^\[\]"'\s]+\.(?:png|jpe?g|gif|webp))"#,
    );
    bb.captures(contents).map(|c| c[1].to_string())
}

/// Strip BBCode/HTML/URLs and collapse whitespace, truncating on a word
/// boundary to roughly `max` characters.
pub fn excerpt(contents: &str, max: usize) -> String {
    static TAGS: OnceLock<Regex> = OnceLock::new();
    static IMG_BLOCK: OnceLock<Regex> = OnceLock::new();
    static URLS: OnceLock<Regex> = OnceLock::new();
    static SPACE: OnceLock<Regex> = OnceLock::new();

    let img_block = re(
        &IMG_BLOCK,
        r"(?is)\[img[^\]]*\].*?\[/img\]|\[previewyoutube[^\]]*\].*?\[/previewyoutube\]",
    );
    let tags = re(&TAGS, r"(?s)\[/?[a-zA-Z0-9*]+(?:[ =][^\]]*)?\]|<[^>]+>");
    let urls = re(&URLS, r"\{STEAM_CLAN_IMAGE\}\S*|https?://\S+");
    let space = re(&SPACE, r"\s+");

    let s = img_block.replace_all(contents, " ");
    let s = tags.replace_all(&s, " ");
    let s = urls.replace_all(&s, " ");
    let s = s
        .replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&nbsp;", " ")
        .replace("\\", " ");
    let s = space.replace_all(&s, " ").trim().to_string();

    if s.chars().count() <= max {
        return s;
    }
    let mut cut: String = s.chars().take(max).collect();
    if let Some(i) = cut.rfind(' ') {
        cut.truncate(i);
    }
    let cut = cut.trim_end_matches(|c: char| c.is_ascii_punctuation());
    format!("{cut}…")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolves_clan_images() {
        let body = "[p][img src=\"{STEAM_CLAN_IMAGE}/3381077/abc123.png\"][/img][/p] Hello";
        assert_eq!(
            first_image(body).as_deref(),
            Some("https://clan.akamai.steamstatic.com/images/3381077/abc123.png")
        );
    }

    #[test]
    fn strips_markup() {
        let body = "[h1]Patch notes[/h1][list][*]Fixed a crash[*]Faster loads[/list] <p>See https://example.com</p>";
        assert_eq!(
            excerpt(body, 200),
            "Patch notes Fixed a crash Faster loads See"
        );
    }

    #[test]
    fn truncates_on_word_boundary() {
        let out = excerpt("alpha beta gamma delta", 12);
        assert_eq!(out, "alpha beta…");
    }
}
