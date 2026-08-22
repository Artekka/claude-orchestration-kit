---
name: feedback-link-not-relative-path
description: "Deliverables for Art: HTML/viewable docs → host PUBLICLY on the project's public web host (mobile-viewable); images & other plain files → Windows UNC path (\\\\wsl.localhost\\<distro>\\...) for Explorer copy/paste. Never localhost-only HTML, never bare Linux paths."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a6c7a60b-9b62-4429-9d62-7653c4f680ce
  modified: 2026-08-09T22:19:33.189Z
---

Whenever Art asks for an HTML file, prototype page, report, or any viewable document, I must **host it over HTTP** and hand him a **plain, full `http://localhost:<port>/...` URL** he can copy/paste into his Windows browser. Display the URL as bare text on its own line so it's easy to select. **Never** give only a relative path like `docs/prototypes/foo.html`, and don't rely on a clickable link.

**Why:** Art runs Claude Code inside WSL from a **Windows 11 PowerShell terminal where links are NOT clickable** — he can only copy/paste. A relative path (or an unclickable `file://` link) makes him do extra work to actually open the thing. He called this out explicitly on 2026-07-11 (twice, clarifying) after I referenced `docs/prototypes/battle-fx-preview.html` relatively. WSL2 forwards listening ports to Windows `localhost`, so a `python3 -m http.server` bound in WSL is reachable at `http://localhost:<port>` from the Windows browser.

**How to apply:** For every viewable deliverable: (1) start a detached static server if one isn't already up — `setsid python3 -m http.server <port> --bind 0.0.0.0 --directory <repo root> > <log> 2>&1 < /dev/null &` (use `setsid` + `< /dev/null` so it survives the tool call; `run_in_background` alone did NOT persist here). Serving the **repo root** lets one server cover every doc/prototype. (2) `curl` the path to confirm HTTP 200. (3) Show the bare URL, e.g. `http://localhost:8123/docs/prototypes/battle-fx-preview.html`. Check for an existing server first (`ss -ltn`) and reuse its port if it already serves the repo; pick another port if it serves something else (port 8099 was taken by an unrelated asset server on 2026-07-11, so I used 8123). Also SendUserFile the artifact as a convenience. Related: `feedback_hud_design_workflow`, `feedback_surface_errors_onscreen_no_devtools`.

**UNC-path addendum (Art, 2026-08-09):** For NON-HTML file deliverables (screenshots, PNGs, exports) where hosting is overkill, give the **Windows UNC form** of the path so it's clickable/pasteable in Explorer: prefix `\\wsl.localhost\Ubuntu-24.04`, then the Linux path with every `/` flipped to `\`. Example: `/tmp/claude-1000/foo/bar.png` → `\\wsl.localhost\Ubuntu-24.04\tmp\claude-1000\foo\bar.png`. Raw Linux paths in tool output are NOT clickable on his Windows terminal. Directory-level UNC (to the containing folder) is fine when delivering a batch.

**Final split (Art, 2026-08-09, two corrections same day — this is the settled rule):**
- **HTML / viewable documents → host PUBLICLY on the project's public web host** so Art can view on mobile away from home (localhost-only hosting rejected for this reason). Recipe shape: `docker exec <web-container> mkdir -p <deliverables dir> && docker cp <file> <web-container>:<deliverables dir>/<name>` → curl-verify → hand the bare `https://<project-host>/deliverables/<name>` URL. Ephemeral (cleared by the next deploy rebuild); each project's container/domain analogously.
- **Images and other plain files → LOCAL UNC path only** (`\\wsl.localhost\Ubuntu-24.04\<path with backslashes>`, folder-level for batches) for Explorer copy/paste — Art explicitly rolled back my brief everything-public reading: "only HTML files should be hosted online."
- **Cloudflare-cache warning:** anything copied under the public web root is published — nginx's static-asset location stamps `max-age=31536000, immutable` and Cloudflare edge-caches it, so deleting from the container does NOT unpublish (verified 2026-08-09: PNGs kept serving cf-cache-status HIT after origin removal; purge needs the CF dashboard). Don't put non-HTML or anything remotely sensitive there.
