pragma Singleton

import Quickshell
import Quickshell.Hyprland

// The workspaces the bar draws, and switching between them.
//
// Hyprland reports named and special workspaces with negative ids and lists
// them first; the strip is about the numbered ones you move between, so this
// keeps those and puts them in order. A workspace exists here whether or not
// it has windows in it — you can be standing on an empty one, and a strip
// that dropped it would renumber itself underneath you.
Singleton {
    id: root

    readonly property var all: {
        const out = [];
        const list = Hyprland.workspaces.values;

        for (let i = 0; i < list.length; i++) {
            if (list[i].id > 0)
                out.push(list[i]);
        }

        out.sort((a, b) => a.id - b.id);
        return out;
    }

    readonly property int count: root.all.length

    // Where the focused workspace sits in `all`, or -1 when none of them is
    // focused — a special workspace toggled over the top, say.
    readonly property int focusedIndex: root.all.findIndex(w => w.focused)

    // Which spelling of the dispatcher this Hyprland wants — the same split
    // as logging out, and for the same reason: under the Lua config layer
    // `hyprctl dispatch` evaluates its argument as a Lua expression, so the
    // plain dispatcher name parses as a bare identifier and is refused.
    //
    // A binding rather than a read at the moment of the click: `usingLua` is
    // false until the module has asked Hyprland what it is running, and the
    // answer lands a moment after the singleton is built.
    readonly property bool lua: Hyprland.usingLua

    function focus(workspace: var): void {
        if (!workspace || workspace.focused)
            return;

        // `hl.dsp.focus({ workspace = n })` is the form hyprland.lua's own
        // SUPER+[0-9] binds use, so clicking a dot and pressing the keybind
        // go the same way.
        Hyprland.dispatch(root.lua ? `hl.dsp.focus({ workspace = ${workspace.id} })` : `workspace ${workspace.id}`);
    }
}
