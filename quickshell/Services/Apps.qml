pragma Singleton

import Quickshell

// The desktop application list, and the search over it.
//
// DesktopEntries populates a beat after startup like everything else here,
// so `all` is a binding rather than something read once.
//
// Ranking is deliberately crude: a name that starts with what you typed beats
// one that merely contains it, which beats a match on the generic name,
// keywords or the desktop id. That ordering is what makes two or three
// letters land on the thing you meant.
Singleton {
    id: root

    property string query: ""

    readonly property var all: {
        const out = [];
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            if (!apps[i].noDisplay)
                out.push(apps[i]);
        }
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    readonly property var results: {
        const needle = root.query.trim().toLowerCase();
        if (needle === "")
            return root.all;

        const scored = [];
        for (let i = 0; i < root.all.length; i++) {
            const rank = root.rank(root.all[i], needle);
            if (rank > 0)
                scored.push({ app: root.all[i], rank: rank });
        }

        // Ties break alphabetically, so the order is stable as you type.
        scored.sort((a, b) => b.rank - a.rank || a.app.name.localeCompare(b.app.name));
        return scored.map(entry => entry.app);
    }

    function rank(app: var, needle: string): int {
        const name = app.name.toLowerCase();
        if (name.startsWith(needle))
            return 100;
        if (name.includes(needle))
            return 60;
        if ((app.genericName || "").toLowerCase().includes(needle))
            return 40;
        // keywords is a string list, not a string.
        if ((app.keywords || []).join(" ").toLowerCase().includes(needle))
            return 30;
        if ((app.id || "").toLowerCase().includes(needle))
            return 20;
        return 0;
    }

    function launch(app: var): void {
        if (app)
            app.execute();
    }
}
