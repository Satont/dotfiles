import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, SelectList, matchesKey, visibleWidth, type SelectItem } from "@earendil-works/pi-tui";
import { existsSync, readFileSync, readdirSync, openSync, readSync, closeSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// ── Config ─────────────────────────────────────────────────────────────

interface ShortcutConfig {
  /** Map of shortcut key to action id, e.g. "ctrl+p" → "palette".
   *  Set to false to disable a shortcut entirely.
   *  Omit the whole field (or file) to register all defaults. */
  shortcuts?: Record<string, string | false>;
}

const CONFIG_PATH = join(homedir(), ".pi", "agent", "pi-command-palette.json");

function loadConfig(): ShortcutConfig | null {
  try {
    if (existsSync(CONFIG_PATH)) {
      return JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
    }
  } catch { /* ignore corrupted config */ }
  return null;
}

// ── Types ──────────────────────────────────────────────────────────────

interface PaletteItem {
  id: string;
  label: string;
  description: string;
  run?: () => Promise<void>;
  children?: () => PaletteItem[];
}

interface MenuLevel {
  title: string;
  items: PaletteItem[];
  map: Map<string, PaletteItem>;
  selectList: SelectList;
  filterInput: FilterInput;
}

// ── Extension ──────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // ── Load config ────────────────────────────────────────────────────
  const cfg = loadConfig();
  // ──── Palette shortcut ────────────────────────────────────────────
  // Default: not registered (to avoid interfering with pi's native
  // Ctrl+P for model cycling).  Users opt in via config:
  //   { "shortcuts": { "ctrl+p": true } }
  const shortcuts = cfg?.shortcuts;
  const paletteEnabled = shortcuts?.["ctrl+p"] === true;
  if (paletteEnabled) {
    pi.registerShortcut("ctrl+p", {
      description: "Open command palette",
      handler: async (ctx) => {
        await showPalette(ctx, pi);
      },
    });
  }

  // ──── Other shortcuts are built-in actions ─────────────────────────
  // ctrl+t  → app.thinking.cycle  (configure in keybindings.json)
  // shift+tab → app.model.cycleForward  (configure in keybindings.json)
  //
  // /palette command is always available regardless of config.
  pi.registerCommand("palette", {
    description: "Open palette",
    handler: async (_args, ctx) => {
      await showPalette(ctx, pi);
    },
  });
}

// ── Entry ─────────────────────────────────────────────────────────────

type PaletteResult = (() => Promise<void>) | null;

type PaletteOverlayRuntime = {
  handle?: any;
  closed?: boolean;
  finish?: () => void;
  close?: () => void;
  result?: PaletteResult;
};

async function showPalette(ctx: ExtensionCommandContext, pi: ExtensionAPI) {
  if (!ctx.hasUI) return;
  const rootItems = buildRootItems(ctx, pi);
  const runtime: PaletteOverlayRuntime = {};

  const closeRuntime = () => {
    if (runtime.closed) return;
    runtime.closed = true;
    runtime.handle?.hide?.();
    runtime.finish?.();
  };
  runtime.close = closeRuntime;

  await ctx.ui.custom<void>(
    async (tui, theme, keybindings, done) => {
      runtime.finish = () => done();

      const overlay = new PaletteComponent(tui, theme, (result) => {
        runtime.result = result;
        runtime.close?.();
      }, rootItems);

      runtime.close = () => {
        overlay.dispose?.();
        closeRuntime();
      };

      if (runtime.closed) done();
      return overlay;
    },
    {
      overlay: true,
      overlayOptions: {
        anchor: "top-center",
        width: "60%",
        margin: { top: 3 },
        nonCapturing: true,
      },
      onHandle: (handle) => {
        runtime.handle = handle;
        handle.focus?.();
        if (runtime.closed) closeRuntime();
      },
    },
  );

  if (runtime.result) await runtime.result();
}

// ── Build root menu ───────────────────────────────────────────────────

function buildRootItems(ctx: ExtensionCommandContext, pi: ExtensionAPI): PaletteItem[] {
  const items: PaletteItem[] = [];

  items.push({
    id: "model", label: "Switch Model", description: "Choose a model (Shift+Tab to cycle)",
    children: () => buildModelList(ctx, pi),
  });
  items.push({
    id: "think", label: "Set Thinking Level", description: "Change thinking level (Ctrl+T to cycle)",
    children: () => buildThinkList(ctx, pi),
  });
  items.push({
    id: "new-session", label: "New Session", description: "Start a fresh session",
    run: async () => { await ctx.newSession(); },
  });
  items.push({
    id: "fork-session", label: "Fork Session", description: "New session linked to current",
    run: async () => { const p = ctx.sessionManager.getSessionFile(); await ctx.newSession({ parentSession: p ?? undefined }); },
  });
  items.push({
    id: "resume", label: "Resume Session", description: "Switch to a saved session",
    children: () => buildSessionList(ctx),
  });
  items.push({
    id: "compact", label: "Compact Session", description: "Trigger context compaction",
    run: async () => { ctx.compact(); ctx.ui.notify("Compaction triggered", "info"); },
  });
  items.push({
    id: "reload", label: "Reload Session", description: "Reload extensions / keybindings / etc",
    run: async () => { await ctx.reload(); },
  });
  items.push({
    id: "session-info", label: "Session Info", description: "Show session name, ID, leaf",
    run: async () => {
      const sid = ctx.sessionManager.getSessionId();
      const name = ctx.sessionManager.getSessionName();
      const leaf = ctx.sessionManager.getLeafId();
      ctx.ui.notify(`session: ${name || sid.slice(0, 12)}\nid: ${sid}\nleaf: ${leaf ? leaf.slice(0, 12) + "…" : "root"}`, "info");
    },
  });
  items.push({
    id: "pin-pos", label: "Pin Position", description: "Save tree position (pi-session-anchor)",
    run: async () => {
      const leafId = ctx.sessionManager.getLeafId();
      const sid = ctx.sessionManager.getSessionId();
      await saveAnchor(sid, leafId);
      ctx.ui.notify(leafId ? "Pinned ✓" : "Root pinned ✓", "info");
    },
  });
  items.push({
    id: "show-anchor", label: "Show Anchor", description: "Check saved tree anchor",
    run: async () => {
      const sid = ctx.sessionManager.getSessionId();
      const saved = await loadAnchor(sid);
      const cur = ctx.sessionManager.getLeafId();
      if (!saved) { ctx.ui.notify("No anchor saved", "info"); return; }
      ctx.ui.notify(
        saved === "root"
          ? "Anchor → root"
          : `Anchor → ${saved.slice(0, 8)}…  (now: ${cur?.slice(0, 8) ?? "root"}…)`,
        "info",
      );
    },
  });
  items.push({
    id: "toggle-tool", label: "Toggle Tool", description: "Enable / disable a tool",
    children: () => buildToolToggleList(ctx, pi),
  });
  items.push({
    id: "about", label: "About pi", description: "Version, hotkeys, reference",
    children: () => buildAboutList(ctx),
  });

  return items;
}

// ── Sub-list builders ──────────────────────────────────────────────────

function buildModelList(ctx: ExtensionCommandContext, pi: ExtensionAPI): PaletteItem[] {
  // Only authenticated + enabled models — the same set `--model` / the model
  // selector see — instead of the full provider catalog.
  const all = (ctx.models ? ctx.models.list() : ctx.modelRegistry.getAll()) ?? [];
  const current = pi.getModel?.();
  const items = all
    .map((m) => ({
      id: `m:${m.provider}/${m.id}`,
      label: `${m.provider}/${m.id}`,
      description:
        current && current.provider === m.provider && current.id === m.id ? "current model" : "",
      run: async () => {
        await pi.setModel(m);
        ctx.ui.notify(`→ ${m.provider}/${m.id}`, "info");
      },
    }))
    .sort((a, b) => a.label.localeCompare(b.label));
  if (items.length === 0) {
    return [{ id: "none", label: "(no models available)", description: "", run: async () => {} }];
  }
  return items;
}

function buildThinkList(ctx: ExtensionCommandContext, pi: ExtensionAPI): PaletteItem[] {
  const levels = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;
  const cur = pi.getThinkingLevel();
  return levels.map((lvl) => ({
    id: `t:${lvl}`,
    label: lvl === cur ? `● ${lvl}` : `  ${lvl}`,
    description: lvl === cur ? "active" : "",
    run: async () => { pi.setThinkingLevel(lvl); ctx.ui.notify(`Thinking: ${lvl}`, "info"); },
  }));
}

function buildSessionList(ctx: ExtensionCommandContext): PaletteItem[] {
  const sessions = listSessions(ctx);
  if (sessions.length === 0) {
    return [{ id: "nosess", label: "(no sessions)", description: "", run: async () => {} }];
  }
  return sessions.map((s) => ({
    id: `rs:${s.path}`, label: s.label, description: "Switch session",
    run: async () => { await ctx.switchSession(s.path); },
  }));
}

function buildToolToggleList(ctx: ExtensionCommandContext, pi: ExtensionAPI): PaletteItem[] {
  const all = pi.getAllTools();
  if (all.length === 0) {
    return [{ id: "nt", label: "(no tools)", description: "", run: async () => {} }];
  }
  const active = pi.getActiveTools();
  return all.map((t) => {
    const on = active.includes(t.name);
    return {
      id: `tl:${t.name}`,
      label: `${on ? "✓" : " "} ${t.name}`,
      description: on ? "enabled — tap to disable" : "disabled — tap to enable",
      run: async () => {
        pi.setActiveTools(on ? active.filter((n) => n !== t.name) : [...active, t.name]);
        ctx.ui.notify(`${t.name} ${on ? "OFF" : "ON"}`, "info");
      },
    };
  });
}

function buildAboutList(ctx: ExtensionCommandContext): PaletteItem[] {
  const commands = [
    ["settings", "Open settings menu"],
    ["model <provider/model>", "Select model"],
    ["scoped-models", "Enable/disable models for Ctrl+P"],
    ["export", "Export session (HTML / .jsonl)"],
    ["import", "Import session from JSONL"],
    ["share", "Share as secret GitHub gist"],
    ["copy", "Copy last agent message"],
    ["name", "Set session display name"],
    ["changelog", "Show changelog"],
    ["hotkeys", "Show keyboard shortcuts"],
    ["clone", "Duplicate session at current position"],
    ["tree", "Navigate session tree"],
    ["trust", "Save project trust decision"],
    ["login <provider>", "Configure provider auth"],
    ["logout", "Remove provider auth"],
    ["quit", "Exit pi"],
  ];

  return commands.map(([name, desc]) => ({
    id: `ref:${name}`,
    label: `/${name}`,
    description: desc,
    run: async () => { ctx.ui.notify(`Type /${name} in the input line`, "info"); },
  }));
}

// ── Sidecar helpers ────────────────────────────────────────────────────

const STORAGE_DIR = join(homedir(), ".pi", "agent", "state", "session-anchor");

async function saveAnchor(sid: string, leafId: string | null): Promise<void> {
  const { mkdir, writeFile } = await import("node:fs/promises");
  await mkdir(STORAGE_DIR, { recursive: true });
  await writeFile(join(STORAGE_DIR, `${sid}.json`), JSON.stringify({ leafId, updatedAt: new Date().toISOString() }), "utf8");
}

async function loadAnchor(sid: string): Promise<"root" | string | null> {
  try {
    const { readFile } = await import("node:fs/promises");
    const raw = await readFile(join(STORAGE_DIR, `${sid}.json`), "utf8");
    const d = JSON.parse(raw);
    if (d.leafId === null) return "root";
    return typeof d.leafId === "string" ? d.leafId : null;
  } catch { return null; }
}

// ── Session listing ────────────────────────────────────────────────────

interface SessionInfo { path: string; label: string; }

function listSessions(ctx: ExtensionCommandContext): SessionInfo[] {
  const dir = ctx.sessionManager.getSessionDir();
  try {
    return readdirSync(dir)
      .filter((f) => f.endsWith(".jsonl"))
      .sort().reverse().slice(0, 25)
      .map((f) => {
        const full = join(dir, f);
        let label = f;
        try {
          const hdr = readFirstLine(full);
          if (hdr) { const p = JSON.parse(hdr); if (p.name) label = p.name; }
        } catch {}
        return { path: full, label };
      });
  } catch { return []; }
}

function readFirstLine(p: string): string | null {
  try {
    const fd = openSync(p, "r");
    const buf = Buffer.alloc(4096);
    const n = readSync(fd, buf, 0, 4096, 0);
    closeSync(fd);
    const s = buf.toString("utf8", 0, n);
    const nl = s.indexOf("\n");
    return nl >= 0 ? s.slice(0, nl) : s;
  } catch { return null; }
}

// ── Floating Component ─────────────────────────────────────────────────

class FilterInput {
  value = "";
  cursor = 0;

  private clamp(): void {
    this.cursor = Math.max(0, Math.min(this.cursor, this.value.length));
  }

  handleInput(data: string): boolean {
    if (matchesKey(data, "left")) {
      if (this.cursor > 0) this.cursor -= 1;
      return true;
    }
    if (matchesKey(data, "right")) {
      if (this.cursor < this.value.length) this.cursor += 1;
      return true;
    }
    if (matchesKey(data, "home") || matchesKey(data, "ctrl+a")) {
      this.cursor = 0;
      return true;
    }
    if (matchesKey(data, "end") || matchesKey(data, "ctrl+e")) {
      this.cursor = this.value.length;
      return true;
    }
    if (matchesKey(data, "delete")) {
      if (this.cursor < this.value.length) {
        this.value = this.value.slice(0, this.cursor) + this.value.slice(this.cursor + 1);
      }
      return true;
    }
    if (data === "backspace" || data === "\x7f" || data === "\b") {
      if (this.cursor > 0) {
        this.value = this.value.slice(0, this.cursor - 1) + this.value.slice(this.cursor);
        this.cursor -= 1;
      }
      return true;
    }
    if (matchesKey(data, "ctrl+u")) {
      this.value = "";
      this.cursor = 0;
      return true;
    }
    if (matchesKey(data, "ctrl+w") || data === "\x17") {
      const left = this.value.slice(0, this.cursor);
      const trimmed = left.replace(/\s+$/, "");
      const boundary = Math.max(trimmed.lastIndexOf(" ") + 1, 0);
      this.value = left.slice(0, boundary) + this.value.slice(this.cursor);
      this.cursor = boundary;
      this.clamp();
      return true;
    }
    if (data.length === 1) {
      const cc = data.charCodeAt(0);
      if (cc >= 32 && cc !== 127) {
        this.value = this.value.slice(0, this.cursor) + data + this.value.slice(this.cursor);
        this.cursor += data.length;
        return true;
      }
    }
    return false;
  }

  render(width: number): string {
    const w = Math.max(1, width);
    const start = Math.max(0, this.cursor - Math.max(0, w - 1));
    const before = this.value.slice(start, this.cursor);
    const at = this.value.slice(this.cursor, this.cursor + 1) || " ";
    const after = this.value.slice(this.cursor + (this.cursor < this.value.length ? 1 : 0));
    const afterVisible = after.slice(0, Math.max(0, w - before.length - 1));
    const content = `${before}${CURSOR_MARKER}\x1b[7m${at}\x1b[27m${afterVisible}`;
    const pad = Math.max(0, w - visibleWidth(content));
    return `${content}${" ".repeat(pad)}`;
  }
}

class PaletteComponent {
  private stack: MenuLevel[] = [];
  private tui: any;
  private theme: any;
  private done: (result: PaletteResult) => void;
  private disposed = false;

  constructor(tui: any, theme: any, done: (result: PaletteResult) => void, rootItems: PaletteItem[]) {
    this.tui = tui;
    this.theme = theme;
    this.done = done;
    this.pushLevel("⌕", rootItems);
  }

  dispose(): void {
    this.disposed = true;
  }

  // ── Stack management ────────────────────────────────────────────────

  private makeSelectList(items: PaletteItem[], map: Map<string, PaletteItem>): SelectList {
    const rows = this.tui.terminal?.rows ?? 25;
    const maxVisible = Math.max(4, Math.floor(rows * 0.35) - 2);

    const selectItems: SelectItem[] = [];
    for (const item of items) {
      const descParts: string[] = [];
      if (item.description) descParts.push(item.description);
      if (item.children) descParts.push(this.theme.fg("muted", "→ sub"));
      selectItems.push({
        value: item.label,
        label: item.label,
        description: descParts.length > 0 ? descParts.join("  ") : undefined,
      });
    }

    const sl = new SelectList(selectItems, maxVisible, {
      selectedPrefix: (t: string) => this.theme.fg("accent", "▸ ") + t,
      selectedText: (t: string) => this.theme.bold(this.theme.fg("accent", t)),
      description: (t: string) => this.theme.fg("dim", t),
      scrollInfo: (t: string) => this.theme.fg("muted", t),
      noMatch: (t: string) => this.theme.fg("dim", t),
    });

    sl.onSelect = (sel) => this.onSelect(sel, map);
    sl.onCancel = () => this.onCancel();
    return sl;
  }

  private pushLevel(title: string, items: PaletteItem[]) {
    const map = new Map<string, PaletteItem>();
    for (const item of items) map.set(item.label, item);
    const sl = this.makeSelectList(items, map);
    this.stack.push({ title, items, map, selectList: sl, filterInput: new FilterInput() });
  }

  private applyFilter(level: MenuLevel) {
    const filter = level.filterInput.value;
    const lower = filter.toLowerCase();
    const filtered = filter
      ? level.items.filter(
          (it) => it.label.toLowerCase().includes(lower) || it.description.toLowerCase().includes(lower),
        )
      : level.items;
    level.selectList = this.makeSelectList(filtered, level.map);
  }

  // ── Events ─────────────────────────────────────────────────────────

  private onSelect(selItem: SelectItem, map: Map<string, PaletteItem>) {
    const item = map.get(selItem.value);
    if (!item) return;
    if (item.children) {
      const sub = item.children();
      if (sub.length === 0) return;
      this.pushLevel(item.label, sub);
      this.tui.requestRender();
      return;
    }
    if (item.run && !this.disposed) this.done(item.run);
  }

  private onCancel() {
    if (this.stack.length > 1) {
      this.stack.pop();
      this.tui.requestRender();
    } else {
      if (!this.disposed) this.done(null);
    }
  }

  // ── Keyboard ───────────────────────────────────────────────────────

  handleInput(data: string): void {
    if (matchesKey(data, "ctrl+c") || matchesKey(data, "ctrl+d")) { if (!this.disposed) this.done(null); return; }
    const level = this.stack[this.stack.length - 1];
    if (!level) return;

    if (level.filterInput.handleInput(data)) {
      this.applyFilter(level);
      this.tui.requestRender();
      return;
    }

    level.selectList.handleInput(data);
    this.tui.requestRender();
  }

  // ── Render ──────────────────────────────────────────────────────────

  private visualLen(s: string): number {
    return visibleWidth(s);
  }

  invalidate(): void {
    for (const l of this.stack) l.selectList.invalidate();
  }

  render(width: number): string[] {
    const maxW = Math.min(Math.max(width - 2, 40), 80);
    const level = this.stack[this.stack.length - 1];
    if (!level) return [];

    const crumbs = this.stack.map((l) => l.title === "⌕" ? "⌕" : l.title).join("  ›  ");
    const prefix = `${crumbs} ${this.theme.fg("dim", "|")} `;
    const inputWidth = Math.max(1, maxW - 1 - this.visualLen(prefix));
    const inputLine = level.filterInput.render(inputWidth);
    const header = `${prefix}${inputLine}`;
    const pad = Math.max(0, maxW - 1 - this.visualLen(header));

    // Render list with content width = maxW - 2 (reserving │ spaces)
    const contentW = maxW - 2;
    const listLines = level.selectList.render(contentW);

    const borders = [
      `┌${"─".repeat(maxW)}┐`,
      `│ ${header}${" ".repeat(pad)}│`,
      `├${"─".repeat(maxW)}┤`,
      ...listLines.map((raw) => {
        const visual = this.visualLen(raw);
        // Align to maxW + 2 total: │ (1) + space (1) + content + pad + │ (1) = maxW + 2
        const rightPad = Math.max(0, maxW - 1 - visual);
        return `│ ${raw}${" ".repeat(rightPad)}│`;
      }),
      `└${"─".repeat(maxW)}┘`,
    ];
    return borders;
  }
}
