# Extracting battle routes from Pokeking (CODE → app JSON)

> This article documents how FarmOracleMMO's battle guides are born: extracting routes from
> **Pokeking** with your own account, converting them to the app format and translating them.
> It's the exact process we run on every data update.
>
> 🇧🇷 Versão em português: [Como extrair os roteiros do Pokeking](../como-extrair-roteiros-do-pokeking.md)

## What Pokeking is (and what the CODE does)

**[Pokeking](http://pokeking.icu)** is a Chinese PokeMMO guide that maps, battle by battle, how
to beat the Elite 4: for each of the 25 trainers (5 regions × 5 champions) it holds a **decision
tree** — "opponent sent out X → do Y". It's the source of truth for FarmOracle's solves.

The key detail is the **CODE**: on the site's *account info* page there's a `CODE` field that
defines **which player team** the solutions assume. Change the CODE → the site shows routes
computed for that team (the 25 trainers and their leads stay the same; the **answers** change).
Each FarmOracle team maps to one CODE — they live in the `code` field of
[`data/teams.json`](../../data/teams.json), and the app shows each one so you can apply it.

## What you need

1. **A Pokeking account, logged in in your browser** — the API only answers with your session
   cookie (`web-token`, a JWT that expires within hours). You can't extract "from outside".
2. **The CODE of the team** you want to extract (e.g. from `data/teams.json`, or a new CODE
   shared by the community).
3. Python 3 for the conversion (`tools/build_elite4.py`).

## Step 1 — Apply the CODE

On the site (logged in): **account info → CODE field → paste → save**. From then on all Elite 4
navigation shows that team's routes.

## Step 2 — Extract via the Console (F12)

Open DevTools (**F12 → Console**) on any page of the logged-in site and paste the entire
contents of [`tools/extract-pokeking-console.js`](../../tools/extract-pokeking-console.js) → Enter.

- The script walks the 5 regions → 25 champions → every lead, builds a single JSON and
  **downloads `pokeking_full.json`** (~500 KB, in Chinese) to your Downloads folder.
- If Chrome blocks pasting, type `allow pasting` + Enter and paste again.
- There's a **sanity check**: fewer than 5 regions / 25 champions / 100 leads (dead session,
  wrong CODE) → it refuses to download and warns you in the console.

### How the API was discovered (the fun part)

Every menu click on Pokeking reloads the page, so hooking XHR in the Console never survived.
The way in was the **Network** tab with *Preserve log* on: clicking a lead revealed the
`findRouter` call; **Copy as cURL** exposed the base URL (`http://backend.pokeking.icu/api/`),
the parameters and the `web-token` cookie. From there, probing sibling endpoints in the Console
led to the ones that matter:

| Endpoint | Purpose |
|---|---|
| `area/list` | lists the 6 areas (the 5 E4 regions + "other": Red and the Pumpkin King) |
| `npc/listByArea?area=<code>` | the 5 champions of a region |
| `monsterRouter/listByNpc?npcId=<N>` | ⭐ the **full tree of every lead** of one champion |

⭐ is the trick: `listByNpc` returns everything at once, so a full extraction is only
**~25 requests**. The backend allows CORS for the site's own origin, which is why the script
runs in the Console (with `credentials: 'include'`) with nothing to install.

### The raw format

Each tree node has `label` (the Pokémon the opponent sent out, in Chinese), `operate` (your
turn's actions), `attention` (warnings) and `children` (the branches — each child is a possible
answer to "what did the opponent do?").

## Step 3 — Convert to the app format

```bash
mv ~/Downloads/pokeking_full.json tools/
python3 tools/build_elite4.py                 # → data/elite4_<region>.json
```

For a specific team (the Chinese nicknames of YOUR Pokémon differ per team — `蛙` is Toxicroak
on one team and Poliwrath on another), export the `POKEKING_TEAM` env var:

```bash
POKEKING_TEAM=dingxianyou python3 tools/build_elite4.py tools/pokeking_full.json data/teams/dingxianyou
```

Configured teams live in the `TEAMS` dict of [`tools/clear_translate.py`](../../tools/clear_translate.py)
— a new team is one new entry there (member→Pokémon, buff stat, aliases).

> 💡 Build into a test directory first (`tools/_test_out`) and diff against the current `data/`
> before overwriting.

## Step 4 — Translation and review

CN→PT/EN translation is automatic ([`clear_translate.py`](../../tools/clear_translate.py) +
[`pokeking-dictionary.json`](../../tools/pokeking-dictionary.json), longest keys first), **but it
never reaches 100%**: a fresh build leaves a handful of Chinese or raw-English fragments per
region. After building:

1. `python3 tools/export_elite4_txt.py` — renders readable `.txt` trees for review.
2. Fix things **in the dictionary** (not in the final JSON) whenever possible — the next
   re-extraction then comes out clean by itself.
3. Golden rule: **when a battle is ambiguous, don't guess** — check Pokeking itself.

## Bonus 1 — Grabbing the opponents' TEAMS (full catalog)

Beyond the routes, you can extract the **full catalog of the 25 trainers' teams** (every
Pokémon with ability, item and all 4 moves). This data is **CODE-independent** — it's the
site's global table:

```bash
WEB_TOKEN='eyJ...' python3 tools/harvest-pokeking-teams.py
python3 tools/build-opponents-catalog.py      # translates → data/elite4-opponents.json
```

- `WEB_TOKEN` is the value of your logged-in session's `web-token` cookie (F12 → Application →
  Cookies). It expires within hours — extract and use it right away.
- The endpoint behind it is `player/findById?id=N` (the full raw table; `area`/`npc` come null
  and are parsed from `fullName`). `player/lineupMatch` (POST) is the CODE-filtered variant.

## Bonus 2 — Adding a NEW team to the app (via CODE)

Someone in the community shared a new CODE? The full path:

1. **Apply the CODE** on the site and check the team's 6 Pokémon (account info).
2. **Extract** the routes (step 2) — the dump comes out computed for that team.
3. **Register the team** in the `TEAMS` dict of [`tools/clear_translate.py`](../../tools/clear_translate.py):
   each member's Chinese nickname → Pokémon, buff stat and aliases.
4. **Convert** with `POKEKING_TEAM=<team_id>` (step 3) into `data/teams/<team_id>/`.
5. **Add the entry** to [`data/teams.json`](../../data/teams.json) (id, name, CODE, pokémon,
   PokéPaste link) — that manifest is what makes the team show up in the app's selector.
6. Translate/review (step 4) and validate (step 5). Always PT **and** EN.

## Step 5 — Validate

```bash
python3 tools/validate-data.py    # valid JSON + every mode of every team present
python3 tools/parity/check.py     # the data serves all 3 platforms
```

`/data` is copied into the 3 apps at build time — update once, all three ship it.

## Ethics and limits

- **Use your own account** and your own `web-token` — the script runs inside YOUR session.
- **Don't republish the raw dumps** (`pokeking_full.json` etc.): the raw content is Pokeking's
  work. What this repository versions is the **derived, converted and translated** data the app
  consumes — with credit to the source.
- Pokeking is the source of truth for the solves: if the app's guide ever diverges from the
  site, the site wins (and we fix the data).
