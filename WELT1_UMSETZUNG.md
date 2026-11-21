# Parlworld – Welt 1 „Smaragdinsel“: Umsetzung & Dokumentation

Sicherung des Ausgangszustands: `backup/parlworld_original_2026-11-21.rbxl`

## Steuerung
| Aktion | PC | Gamepad | Mobil |
|---|---|---|---|
| Laufen / Sprinten | WASD / Shift | Stick / L3 | Joystick |
| Zielen (manuell) / Visier | Maus / RMB halten | Stick / L2 | Wischen / ZIEL |
| Schießen / Nachladen | LMB / R | R2 / X | FEUER / R |
| Waffen 1–3, Fangkugel | 1, 2, 3 / 4 (Mausrad wechselt) | R1/L1 | WAFFE |
| Fangkugel-Schnellwurf | F | Y | KUGEL |
| Team-Pal rufen/zurück, wechseln | Q / C | DPad ↑ / → | PAL |
| Reiten auf/ab | G | DPad ↓ | REITEN |
| Fliegen hoch/runter | Leertaste / Strg | A / B | HOCH / TIEF |
| Katalog / Ausrüstung / Shop | P / Tab / B | – | Knöpfe oben rechts |
| Interagieren (Händler, Trainer, Altar, Portal) | E | – | Antippen |

## Spielablauf Welt 1
1. Tutorial (oben links, 11 Schritte, serverseitig geprüft): Wegweiser am Südtor → Schießstand (3 Scheiben) → Nachladen → Gackerling besiegen → fangen → Team → Pal rufen → Händler/Kauf → Reiten → Trainer → Boss.
2. Kreaturen besiegen → Geld. Besiegte wilde Pals bleiben 14 s **geschwächt** (Label „FANGBAR! xx %“) → Fangkugel werfen.
3. Händler Bruno (Lager West) oder Shop [B]: Waffen, Tuning, Fangkugel-Stufen, Robux-Angebote.
4. Trainerin Lyra (Übungsring, Nordost): Belohnung vorher angezeigt – Glutwerfer + 400 G + Öffnung des Siegels.
5. Wurzelkessel hinter den Ruinen (Südwest): Altar „Morvath erwecken“. Sieg → Welt 2 freigeschaltet (Portal im Lager zeigt den Status; Inhalt folgt).

## Kreaturen (alle mit eigenem Modell, Animationen, 2 Angriffen + VFX)
| Pal | Element | Seltenheit | Rolle | Angriffe | Reiten |
|---|---|---|---|---|---|
| Gackerling (Startkreatur) | Normal | Gewöhnlich | Unterstützer | Pickschlag (Sprung), Eierbombe (Bogenwurf) | – |
| Glutwiesel | Feuer | Gewöhnlich | Angreifer | Funkensprung (Sprung), Glutspucke (3er-Fächer) | – |
| Moosbock | Pflanze | Gewöhnlich | Tank | Moosramme (Linien-Sturm), Dornenkranz (Ring) | Boden |
| Flauschfunk | Elektro | Ungewöhnlich | Kontrolle | Statikknäuel (langsame Kugel), Donnermal (markierter Blitz) | – |
| Bachzange | Wasser | Ungewöhnlich | Brecher | Scherensichel (Kegel), Blasenmörser (Bogenwurf) | – |
| Frostigel | Eis | Ungewöhnlich | Verteidiger | Stachelsalve (5er-Fächer), Frostnova (Ring + Verlangsamung) | – |
| Surrflügel | Wind | Selten | Luftjäger | Windsichel (Geschoss), Sturzflug (markierter Einschlag) | Fliegen |
| Dämmerluchs | Dunkel | Selten | Assassine | Schattensprung (Teleport), Mondsichelwelle (Strahl) | Boden (schnell) |
| Alpha-Moosbock | Pflanze | Elite | Elite-Tank | wie Moosbock, stärker/schneller | Boden |
| Alpha-Dämmerluchs | Dunkel | Elite | Elite-Assassine | wie Dämmerluchs, stärker/schneller | Boden |
| Morvath, der Wurzelkoloss | Pflanze | Legendär | Boss (nicht fangbar) | Wurzelbeben (Fächer-Bahnen), Sporenmeteor (3 Einschläge); Phase 2 ab 50 % | – |
| Astralhirsch Noxen | Dunkel | Legendär | Premium | Sternenregen, Mondlanze | Fliegen |

## Waffen
Funkenpistole (Start, schwach) · Dornenstreuer (Schrot, kurz) · Schwarmwerfer (Auto) · Falkenauge (Präzision, Zielfernrohr, Kopftreffer ×3) · Glutwerfer (Trainer-Belohnung, Flächenschaden). Tuning je +12 % Schaden, max. 3 Stufen.

## Fangkugeln
Stufe 1 ×1,0 (gratis) · 2 ×1,5 (450 G) · 3 ×2,1 (1.800 G) · 4 ×3,0 (4.800 G).
Chance = Fangrate × Kugel × Level-Faktor (−2 %/Level) × Luck-Boost, begrenzt auf 3–95 %. Fehlwurf: Pal steht mit 30 % LP wieder auf.

## Wo liegt was
- **Configs (zentral):** `ReplicatedStorage.Shared.Config` – `Pals`, `Attacks`, `Weapons`, `Spheres`, `Worlds` (Zonen/Elites/Welten), `Shop` (Boosts/Premium/IDs), `Progression` (Tutorial/Trainer/Boss), `Elements`, `Sounds`
- **Formeln:** `ReplicatedStorage.Shared.Formulas` · **Modelle:** `ReplicatedStorage.Shared.CreatureBuilder`
- **Server:** `ServerScriptService.Server` – `Main`, `Net`, `DataService`, `CreatureService`, `CombatService`, `CaptureService`, `CompanionService`, `ShopService`, `ProgressService`, `SpawnService`
- **Client:** `StarterPlayer.StarterPlayerScripts.ClientMain` + `ClientModules` – `WeaponController`, `Viewmodel`, `HUD`, `Menus`, `Portraits`, `CreatureAnimator`, `VFX`, `RideController`, `WorldClient`, `ClientState`, `UIKit`
- **Welt:** `Workspace.World.Stations` (Händler, Schießstand, Wegweiser, Portal, Übungsring), `Workspace.World.BossArena`

## Robux-Integration (noch nicht konfiguriert!)
In `ReplicatedStorage.Shared.Config.Shop` eintragen:
- `Boosts.luck.productId`, `Boosts.damage.productId`, `Boosts.money.productId` → Developer Products (je 300 Robux)
- `Premium.gamePassId` → Game Pass (1.000 Robux)
Solange `nil`: Shop zeigt „Nicht konfiguriert“, Server lehnt ab, nichts wird simuliert.
Boost-Dauer: `Shop.DefaultBoostDurationSeconds = 1800` (30 Min. Echtzeit, **vorläufiger Standard**), Stapeln bis 6 h.

## Nur vorbereitet
Welt 2 „Glutsteppe“ und Welt 3 „Nebelschlucht“ (Einträge in `Worlds`, Portal/Vorschau), Premium-Varianten Goldschwinge Aurex (W2) und Geisterfuchs Yomira (W3) als Konzept in `Pals.FutureConcepts` / `Shop.Premium.perWorld` – ohne Modell.

## Hinweise
- Speichern nutzt DataStore `ParlworldProfiles_v1`. In Studio ohne „Studio Access to API Services“ läuft eine Sitzung ohne Speicherung (Hinweis im Spiel).
- `ServerStorage.ParlDebug` existiert nur in Studio (Test-Hook), nicht im Live-Spiel.
- Sounds: eingebaute Roblox-Sounds + lizenzierte Pro-Sound-Effects; IDs in `Config.Sounds` austauschbar.
