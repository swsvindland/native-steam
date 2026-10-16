//! Command-line flags (used for screenshot automation and quick testing).

use crate::input::PadAction;
use crate::shell::Tab;

pub const USAGE: &str = "\
Usage: native-steam [OPTIONS]

Options:
  --tab <store|library|community|profile>   Start on this tab
  --game <appId>                            Open the library game page (e.g. 1145350)
  --app <appId>                             Open the store app page
  --input <gamepad|mouse>                   Start in gamepad mode: hints bar + first item focused
  --size <WIDTHxHEIGHT>                     Initial window size (default 1440x900)
  --nav <steps>                             Scripted gamepad presses after startup, comma-separated:
                                            u d l r (D-pad), a, b, y, lb, rb (for screenshots/tests)
  --ignore-pointer                          Ignore the mouse (no hover/tooltips) for clean captures
  --snapshot <path>                         Load a snapshot.json instead of the bundled one
  -h, --help                                Show this help";

#[derive(Clone, Debug, Default)]
pub struct Args {
    pub tab: Option<Tab>,
    pub game: Option<u32>,
    pub app: Option<u32>,
    pub gamepad: bool,
    pub nav: Vec<PadAction>,
    pub size: Option<(i32, i32)>,
    pub snapshot: Option<String>,
    pub ignore_pointer: bool,
    pub help: bool,
}

impl Args {
    pub fn parse(mut it: impl Iterator<Item = String>) -> Result<Args, String> {
        let mut a = Args::default();
        while let Some(arg) = it.next() {
            // Accept both `--flag value` and `--flag=value`.
            let (flag, inline) = match arg.split_once('=') {
                Some((f, v)) if f.starts_with("--") => (f.to_owned(), Some(v.to_owned())),
                _ => (arg.clone(), None),
            };
            let mut value = |name: &str| {
                inline
                    .clone()
                    .or_else(|| it.next())
                    .ok_or_else(|| format!("missing value for {name}"))
            };
            match flag.as_str() {
                "-h" | "--help" => a.help = true,
                "--ignore-pointer" => a.ignore_pointer = true,
                "--tab" => {
                    let v = value("--tab")?;
                    a.tab = Some(Tab::from_name(&v).ok_or_else(|| format!("unknown tab '{v}'"))?);
                }
                "--game" => a.game = Some(parse_id(&value("--game")?)?),
                "--app" => a.app = Some(parse_id(&value("--app")?)?),
                "--input" => {
                    let v = value("--input")?;
                    a.gamepad = match v.as_str() {
                        "gamepad" | "controller" => true,
                        "mouse" | "keyboard" | "touch" => false,
                        _ => return Err(format!("unknown input mode '{v}'")),
                    };
                }
                "--size" => {
                    let v = value("--size")?;
                    let (w, h) = v
                        .split_once(['x', 'X'])
                        .ok_or_else(|| format!("bad size '{v}', expected WIDTHxHEIGHT"))?;
                    let w: i32 = w.trim().parse().map_err(|_| format!("bad width '{w}'"))?;
                    let h: i32 = h.trim().parse().map_err(|_| format!("bad height '{h}'"))?;
                    a.size = Some((w.max(360), h.max(480)));
                }
                "--snapshot" => a.snapshot = Some(value("--snapshot")?),
                "--nav" => {
                    for step in value("--nav")?.split([',', ' ']).filter(|s| !s.is_empty()) {
                        a.nav.push(
                            PadAction::parse(step)
                                .ok_or_else(|| format!("unknown --nav step '{step}'"))?,
                        );
                    }
                }
                other => return Err(format!("unknown argument '{other}'")),
            }
        }
        Ok(a)
    }
}

fn parse_id(s: &str) -> Result<u32, String> {
    s.trim().parse().map_err(|_| format!("bad app id '{s}'"))
}
