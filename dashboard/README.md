# dashboard/

`index_2.html` — the original single-file APEX OS mockup. Kept as the reference
for the approved visual design.

**This file is no longer the thing you run.** It has been superseded by the
desktop app in [`../apex-os/`](../apex-os/), which uses this exact design and
stylesheet but reads live data from Supabase instead of the hardcoded
JavaScript arrays here.

Two things to know if you open this file directly:

- Its `ACCOUNTS` array is a **hand-copied snapshot** of the real accounts and
  risk limits as of 2026-08-12. It was accurate when written, but it does not
  update. Treat `apex-os` as the source of truth for anything you'd act on.
- Everything on the Agent Roster, Org Chart and Super Brain pages is
  illustrative — no agent runtime exists. The desktop app labels this in the
  UI; this file does not.

Design changes should be made in `../apex-os/renderer/` (`styles.css` there is
this file's stylesheet, copied verbatim). This copy is a historical reference.
