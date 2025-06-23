use std::{env, process::Command, time::Instant}; use hyprrust::data::Workspaces;
use s_macro::s;
use serde::{Deserialize, Serialize};
use tokio::{
    net::UnixStream,
};
use tokio_stream::StreamExt;
use tokio_util::codec::{FramedRead, LinesCodec};
use anyhow::{Context, Result};
use std::collections::HashMap;
use gtk::{gdk::keys::constants::t, IconTheme};
use gio::{DesktopAppInfo, Icon as _};
use gtk::IconLookupFlags;

// import the traits needed for .icon() and .lookup_by_gicon()
use gio::prelude::AppInfoExt;
use gtk::prelude::IconThemeExt;


#[derive(Debug, Serialize, Deserialize)]
struct WorkspaceInfo {
    id: i32,
    name: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct Window {
    class: Option<String>,
    title: Option<String>,
    icon: Option<String>,
    monitor: u32,
    #[serde(rename = "focusHistoryID")]
    focus_history_id: i32,
    workspace: Option<WorkspaceInfo>,
}

#[derive(Debug, Serialize)]
struct Icon {
    active: bool,
    path: Option<String>,
}

#[derive(Debug, Serialize)]
struct Icons {
    id: i32,
    workspace: String,
    icons: Vec<Icon>,
}


fn get_icon_path(app: &str) -> anyhow::Result<Option<String>> {
    let icon = match DesktopAppInfo::new(&format!("{}.desktop", app.to_lowercase()))
        .and_then(|info| info.icon()) {
        Some(icon) => icon,
        None => {
            DesktopAppInfo::new(&format!("{}.desktop", app))
                .and_then(|info| info.icon()).context("Failed to get icon for application")?
        }
    };

    // get the default icon theme
    let theme = IconTheme::default().expect("Failed to get default IconTheme");

    // lookup in icon theme (size 32px)
    if let Some(lookup) = theme.lookup_by_gicon(&icon, 32, IconLookupFlags::empty()) {
        if let Some(path) = lookup.filename() {
            return Ok(Some(path.display().to_string()));
        }
    }

    Ok(None)
}

fn get_icons(monitor: u32) -> anyhow::Result<Vec<Icons>> {
    let output = Command::new("hyprctl")
        .arg("clients")
        .arg("-j")
        .output().context("Failed to execute hyprctl clients command")?;
    

    let output = String::from_utf8_lossy(&output.stdout);
    let mut windows: Vec<Window> = serde_json::from_str(&output)
        .context("Invalid JSON input")?;

    let mut icons: Vec<Icons> = Vec::new();

    for mut window in windows.into_iter().filter(|w| w.monitor == monitor) {
        window.icon = match &window.class {
            Some(class) => get_icon_path(class).unwrap_or(None),
            None => None,
        };

        let workspace_id = window.workspace.as_ref()
            .and_then(|ws| Some(ws.id))
            .unwrap_or(0);

        if window.focus_history_id > 0 && workspace_id < 0 {
            continue;
        }


        let paths = icons.iter().position(|w| w.id == workspace_id);

        let icon = Icon {
            active: false,
            path: window.icon.clone(),
        };

        if let Some(index) = paths {
            icons[index].icons.push(icon);
        } else {
            // create a new workspace entry
            let workspace = Icons {
                id: workspace_id,
                workspace: if workspace_id >= 0 {
                    workspace_id.to_string()
                } else {
                    window.workspace.as_ref().map_or("unknown".to_string(), |ws| ws.name.clone()).trim_start_matches("special:").to_string()
                },
                icons: vec![icon],
            };
            icons.push(workspace);
        }
    }

    // sort by id
    icons.sort_by_key(|w| w.workspace.clone());

    // dedup and sort icons for each workspace
    for workspace in icons.iter_mut() {
        workspace.icons.sort_by_key(|w| w.path.clone().unwrap_or_default());
    }

    Ok(icons)
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {

    let args = std::env::args().collect::<Vec<_>>();
    if args.len() != 3 {
        eprintln!("Usage: {} <command> <monitor_id>", args[0]);
        std::process::exit(1);
    }

    if args[1] != "icons" {
        eprintln!("Unknown command: {}", args[1]);
        std::process::exit(1);
    }

    let monitor_id: u32 = args[2].parse().context("Invalid monitor ID")?;

    // initialize GTK (required for IconTheme)
    gtk::init().expect("Failed to initialize GTK");

    let path = format!(
        "{}/hypr/{}/.socket2.sock",
        env::var("XDG_RUNTIME_DIR")?,
        env::var("HYPRLAND_INSTANCE_SIGNATURE")?,
    );

    println!("{}", serde_json::to_string(&get_icons(monitor_id)?).context("Failed to serialize windows")?.trim_start_matches("\"").trim_end_matches("\""));

    let socket = UnixStream::connect(path).await?;
    let mut lines = FramedRead::new(socket, LinesCodec::new());
    while let Some(Ok(line)) = lines.next().await {
        // NOTE: we simply reinitialize the entire state upon each line received. This is significantly simpler than parsing 
        //   the line and updating the state incrementally. This takes roughly 5-50ms per line, which is acceptable for this use case.
        println!("{}", serde_json::to_string(&get_icons(monitor_id)?).context("Failed to serialize windows")?.trim_start_matches("\"").trim_end_matches("\""));
    }

    Ok(())
}

