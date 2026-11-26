# Hold 'til Dawn audio

The soundtrack follows GDD v1, section 6, table 6.3 (MUS-01 through MUS-08).
Source pages and their licences were checked on 2026-11-26. Source archive hashes are in catalog.json.
All imported scores were loudness-adjusted, given short edge fades and transcoded to stereo Ogg Vorbis at 44.1 kHz.
Kenney effects were selected, mixed, trimmed, filtered, pitch-adjusted and given short click-free fades.

| Shipped score | Original / author | Source | Licence |
|---|---|---|---|
| music/menu.ogg | Vault — Alexandr Zhelanov | https://opengameart.org/content/post-apocalypse-more-music-inside ; https://soundcloud.com/alexandr-zhelanov | CC BY 3.0: https://creativecommons.org/licenses/by/3.0/ |
| music/day.ogg | Ruins of an Ancient Culture, from Ambience of a Fallen Age — Umplix | https://opengameart.org/content/ambience-of-a-fallen-age | CC0: https://creativecommons.org/publicdomain/zero/1.0/ |
| music/night_early.ogg | Apocalyptic Loop G — RUOK | https://opengameart.org/content/ruok-apocalyptic-loopstracks ; https://ruok2000.itch.io/ | CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ |
| music/night_late.ogg | Apocalyptic Loop D — RUOK | same source as Loop G | CC BY 4.0 |
| music/boss.ogg | Blackmoor Colossus Loop, from Colossal Boss Battle Theme — Matthew Pablo | https://opengameart.org/content/colossal-boss-battle-theme ; https://www.matthewpablo.com/ | CC BY 3.0 |
| music/final.ogg | Determined Pursuit — Emma_MA | https://opengameart.org/content/determined-pursuit-epic-orchestra-loop | CC0; author declares public domain January 2017 |
| music/loss.ogg | Bittersweet — Emma_MA | https://opengameart.org/content/bittersweet | CC0; author declares public domain January 2017 |
| music/win.ogg | Beacon Home — original game composition | tools/audio_assets.py | Original project audio, no external recording |

Kenney's CC0 foley packs:

- RPG Audio: https://kenney.nl/assets/rpg-audio
- Impact Sounds: https://kenney.nl/assets/impact-sounds
- Interface Sounds: https://kenney.nl/assets/interface-sounds
- Sci-fi Sounds: https://kenney.nl/assets/sci-fi-sounds
- Licence: https://creativecommons.org/publicdomain/zero/1.0/

Creature voices, radio crackle, sirens, medical/radio motifs, island ambience, helicopter and heartbeat
are original layered sound design generated offline by tools/audio_assets.py. They are synthetic effects,
not recordings of the team or of real military communications. No dialogue, paid samples or model-generated
music is used. CC BY and CC0 sources remain under their respective licences. Attribution is also available
from the main menu's AUDIO CREDITS button.

Rebuild: python tools/fetch_audio_sources.py, then python tools/audio_assets.py. Downloads stay in the
ignored .tmp/audio-refresh/sources cache; only the prepared, compact game assets are shipped.
