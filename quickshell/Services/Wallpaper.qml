pragma Singleton

import Quickshell
import Quickshell.Io
import qs.Common

// The pictures on disk, and the link the compositor's wallpaper daemon reads.
//
// Choosing one repoints `Config.wallpaperLink` at a file in
// `Config.wallpaperDir`. Nothing is copied and nothing is written into the
// wallpaper directory — the link *is* the setting, which is why it outlives
// this shell being restarted, replaced, or not running at all. It is the same
// link `install.sh` sets up, so the panel and the installer agree on where
// the wallpaper lives without either knowing about the other.
Singleton {
    id: root

    // One entry per picture: `path` for the link, `url` for the Image, and a
    // `title` for the panel to say out loud.
    property var all: []

    // The link's target as an absolute path, or "" if the link isn't there
    // yet. Set optimistically when you choose one — see `set`.
    property string current: ""

    // Which picture that is, by filename. The comparison has to be by name
    // rather than by path: `readlink -f` resolves every symlink on the way,
    // and with the wallpaper directory itself stowed out of a dotfiles repo,
    // the canonical path of a picture is nothing like the path we listed it
    // under. Both name the same file, and the strip only ever shows one
    // directory, so the filename is identity enough.
    readonly property string currentName: root.current.slice(root.current.lastIndexOf("/") + 1)

    readonly property int count: root.all.length

    // Config's two paths with the `~` expanded. They are written with one in
    // config.json, which has no other way to say "your home directory", and
    // nothing they are handed to — ls, readlink, ln, an image URL — goes
    // through a shell that would expand it.
    readonly property string dirPath: root.expandHome(Config.wallpaperDir)
    readonly property string linkPath: root.expandHome(Config.wallpaperLink)

    // What counts as a picture. Anything Qt can decode without a plugin,
    // which is what the strip has to be able to draw.
    readonly property var extensions: ["jpg", "jpeg", "png", "webp", "bmp"]

    // Where the wallpaper in use sits in the strip, or -1 if it isn't in
    // this directory at all — which is what you get before the first reading
    // lands, and for a link pointing somewhere else entirely.
    readonly property int currentIndex: {
        if (root.currentName === "")
            return -1;

        for (let i = 0; i < root.all.length; i++) {
            if (root.all[i].name === root.currentName)
                return i;
        }
        return -1;
    }

    function isCurrent(entry: var): bool {
        return entry !== null && root.currentName !== "" && entry.name === root.currentName;
    }

    // Both readings are cheap and neither is watched, so the panel asks for
    // them again on the way in: something else may have moved the link or
    // dropped a new picture in the directory since we last looked.
    //
    // This is also the *only* thing that starts them. Quickshell builds
    // every singleton at startup, so a Process left `running: true` here
    // would spawn at every launch and every config reload — twice over, for
    // a panel that is built on demand and may never be opened at all.
    // Nothing outside WallpaperPanel reads any of this, and the panel calls
    // refresh() as it becomes visible, so there is nothing to be gained by
    // knowing any of it earlier.
    function refresh(): void {
        if (!listing.running)
            listing.running = true;
        if (!link.running)
            link.running = true;
    }

    function set(entry: var): void {
        if (!entry || relink.running)
            return;

        // Optimistic. The mark moves with the click rather than a process
        // later, and if the relink fails the next `refresh` puts it back.
        root.current = entry.path;

        relink.command = ["ln", "-sfn", entry.path, root.linkPath];
        relink.running = true;
    }

    // ── Reading ──────────────────────────────────────────────────────────
    // `ls` rather than a directory model: the list is ten files read twice a
    // session, and this way the service hands the panel plain entries like
    // every other service here rather than a model with its own opinions.
    Process {
        id: listing

        command: ["ls", "-1", root.dirPath]

        stdout: StdioCollector {
            onStreamFinished: root.parseListing(this.text)
        }
    }

    // -f resolves the link rather than reporting it, so this is comparable
    // with the paths above however the link was written. Prints nothing when
    // the link doesn't exist, which is the "no wallpaper chosen yet" case.
    Process {
        id: link

        command: ["readlink", "-f", root.linkPath]

        stdout: StdioCollector {
            onStreamFinished: root.current = this.text.trim()
        }
    }

    // ── Writing ──────────────────────────────────────────────────────────
    Process {
        id: relink

        // -n so that a link which somehow already points at a directory is
        // replaced rather than followed — the failure mode there is a stray
        // link *inside* the wallpaper directory, which is exactly the sort of
        // thing nobody notices for a week.
        onExited: code => {
            if (code !== 0 || Config.wallpaperApplyCommand.length === 0)
                return;

            // Detached rather than a child process: this restarts the
            // wallpaper daemon, and a daemon that dies with the shell that
            // asked for it is not a wallpaper daemon.
            Quickshell.execDetached(Config.wallpaperApplyCommand);
        }
    }

    function parseListing(text: string): void {
        const names = text.split("\n").map(line => line.trim()).filter(name => root.accepts(name));
        names.sort((a, b) => a.localeCompare(b));

        root.all = names.map(name => ({
            name: name,
            path: `${root.dirPath}/${name}`,
            url: root.fileUrl(`${root.dirPath}/${name}`),
            title: root.title(name)
        }));
    }

    function accepts(name: string): bool {
        const dot = name.lastIndexOf(".");
        return dot > 0 && root.extensions.indexOf(name.slice(dot + 1).toLowerCase()) >= 0;
    }

    function expandHome(path: string): string {
        if (path === "~" || path.startsWith("~/"))
            return `${Quickshell.env("HOME")}${path.slice(1)}`;
        return path;
    }

    // encodeURI rather than plain concatenation: "night sky.jpg" is an
    // ordinary thing to call a picture, and a space in a URL is not.
    function fileUrl(path: string): string {
        return `file://${encodeURI(path)}`;
    }

    // "the-electric-state.jpg" reads as a filename. "The Electric State"
    // reads as a picture, and pictures are what this panel is showing.
    function title(name: string): string {
        const dot = name.lastIndexOf(".");
        const stem = dot > 0 ? name.slice(0, dot) : name;

        return stem.split(/[-_\s]+/).filter(word => word !== "").map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
    }
}
