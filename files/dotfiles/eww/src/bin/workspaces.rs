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


#[derive(Debug, Deserialize)]
struct Monitor {
    id: u32,
    name: String,
    description: String,
    x: i32,
    y: i32,
}

#[derive(Debug, Serialize, Deserialize)]
struct WorkspaceInfo {
    id: i32,
    name: String,
    #[serde(rename = "monitorID")]
    monitor_id: Option<u32>,
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

#[derive(Debug, Serialize, Deserialize)]
struct Icon {
    active: bool,
    path: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Icons {
    id: i32,
    workspace: String,
    active: bool,
    icons: Vec<Icon>,
}

#[derive(Debug, Deserialize)]
struct ActiveWorkspace {
    id: i32,
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

fn get_active_workspace() -> anyhow::Result<i32> {
    let output = Command::new("hyprctl")
        .arg("activeworkspace")
        .arg("-j")
        .output().context("Failed to execute hyprctl activeworkspace command")?;

    let output = String::from_utf8_lossy(&output.stdout);

    let workspace: ActiveWorkspace = serde_json::from_str(&output)
        .context("Invalid JSON input for active workspace")?;

    Ok(workspace.id)


}

fn init_workspaces(monitor: u32, active_workspace_id: Option<i32>) -> anyhow::Result<Vec<Icons>> {
    let output = Command::new("hyprctl")
        .arg("workspaces")
        .arg("-j")
        .output().context("Failed to execute hyprctl workspaces command")?;

    let output = String::from_utf8_lossy(&output.stdout);
    let icons: Vec<WorkspaceInfo> = serde_json::from_str(&output)
        .context("Invalid JSON input for workspaces")?;

    Ok(icons.into_iter().filter(|ws| ws.monitor_id == Some(monitor as u32))
        .map(|ws| {
        Icons {
            id: ws.id,
            workspace: ws.name.trim_start_matches("special:").to_string(),
            active: active_workspace_id.map_or(false, |id| id == ws.id),
            icons: vec![],
        }
    }).collect())
}

fn get_icons(monitor: u32) -> anyhow::Result<Vec<Icons>> {
    let output = Command::new("hyprctl")
        .arg("clients")
        .arg("-j")
        .output().context("Failed to execute hyprctl clients command")?;


    let output = String::from_utf8_lossy(&output.stdout);
    let mut windows: Vec<Window> = serde_json::from_str(&output)
        .context("Invalid JSON input")?;


    let active_workspace_id = get_active_workspace().ok();

    let mut icons: Vec<Icons> = init_workspaces(monitor, active_workspace_id)?;

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
        }
    }

    // sort by id
    icons.sort_by_key(|w| w.id.clone());

    // dedup and sort icons for each workspace
    for workspace in icons.iter_mut() {
        workspace.icons.sort_by_key(|w| w.path.clone().unwrap_or_default());
    }

    Ok(icons)
}

fn get_monitor_ids() -> anyhow::Result<Vec<u32>> {
    let output = Command::new("hyprctl")
        .arg("monitors")
        .arg("-j")
        .output().context("Failed to execute hyprctl monitors command")?;

    let output = String::from_utf8_lossy(&output.stdout);
    let mut monitors: Vec<Monitor> = serde_json::from_str(&output)
        .context("Invalid JSON input for monitors")?;

    monitors.sort_by_key(|m| (m.x == 0 && m.y == 0, m.id));
    Ok(monitors.into_iter().map(|m| m.id).collect())
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

    let monitor_ids = get_monitor_ids().context("Failed to get monitor IDs")?;
    let monitor_id: u32 = monitor_ids[args[2].parse::<usize>().context("Invalid monitor ID")?];

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

