pragma Singleton

import Quickshell
import Quickshell.Io

// The palettes, and which one is on.
//
// ── Adding a theme ───────────────────────────────────────────────────────
// Append one object to `all`. Every colour in the shell comes from the six
// roles below, so a theme is those six and a name — there is no second place
// to touch and nothing to register.
//
//     {
//         id: "gruvbox",           // what gets written to the theme file
//         name: "Gruvbox Dark",    // what the picker shows
//         surface: "#282828",      // the notch itself
//         text: "#ebdbb2",         // anything you are meant to read
//         textDim: "#a89984",      // labels, captions, things at rest
//         hairline: "#3c3836",     // tiles, rows, tracks — one step up
//         accent: "#83a598",       // today, the on state, the current thing
//         urgent: "#fb4934"        // and nothing else
//     }
//
// Light palettes work without special handling. Nothing in the shell assumes
// dark: the two places that need a colour part-way between a surface and its
// contents derive it from `text` at low alpha, which lightens a dark theme
// and darkens a light one for free.
Singleton {
    id: root

    readonly property var all: [
        {
            id: "mocha",
            name: "Catppuccin Mocha",
            surface: "#1e1e2e",
            text: "#cdd6f4",
            textDim: "#a6adc8",
            hairline: "#313244",
            accent: "#89b4fa",
            urgent: "#f38ba8"
        },
        {
            id: "latte",
            name: "Catppuccin Latte",
            surface: "#eff1f5",
            text: "#4c4f69",
            textDim: "#6c6f85",
            hairline: "#ccd0da",
            accent: "#1e66f5",
            urgent: "#d20f39"
        }
    ]

    // The first theme is the fallback: for a file that isn't there yet, and
    // for one naming a theme that has since been renamed or removed.
    property string currentId: root.all[0].id

    readonly property var current: {
        for (let i = 0; i < root.all.length; i++) {
            if (root.all[i].id === root.currentId)
                return root.all[i];
        }
        return root.all[0];
    }

    readonly property int currentIndex: root.all.indexOf(root.current)

    function isCurrent(theme: var): bool {
        return theme !== null && theme.id === root.currentId;
    }

    function set(theme: var): void {
        if (!theme || theme.id === root.currentId)
            return;

        root.currentId = theme.id;

        // The file is the setting, the same way the wallpaper symlink is: it
        // outlives this shell, and writing it is the whole of what choosing a
        // theme does. Everything else follows from Config's palette being
        // bound to `current`.
        file.setText(`${theme.id}\n`);
    }

    // In the state directory — $XDG_STATE_HOME/halfshell, by shell.qml's
    // StateDir pragma — not beside the shell. This is state, what you last
    // picked, rather than configuration. On a stow-managed setup like this one
    // the shell's directory is a symlink straight into the dotfiles repo, so
    // writing there would dirty a git tree every time anyone changed the
    // theme; in a system install it isn't writable at all. Quickshell creates
    // the directory itself.
    //
    // Not in Config either, unlike the wallpaper paths: Config's palette
    // reads `current`, so a path read back from Config would have the two
    // singletons constructing each other.
    readonly property string path: Quickshell.statePath("theme")

    FileView {
        id: file

        path: root.path
        preload: true

        // So editing the file by hand — or another machine's dotfiles sync
        // landing on it — changes the theme rather than being silently
        // overwritten the next time someone opens the picker.
        watchChanges: true
        onFileChanged: file.reload()

        // A missing file is the ordinary first-run state, not a fault: it
        // means nothing has been chosen and `currentId` keeps its default.
        printErrors: false

        onLoaded: {
            const stored = file.text().trim();
            if (stored !== "")
                root.currentId = stored;
        }
    }
}
