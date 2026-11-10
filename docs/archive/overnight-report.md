---
type: phase-report
status: current
phase: 
date: 2026-11-09
summary: "Report of the overnight run of phases 0, Q3, Q2 and V: documentation, Ask Clap and history, scene states, build state and player."
tags:
  - report
  - archive
---

# Overnight report

Written as the night goes. Order of the night: 0, Q3, Q2, V. Backup of the four folders before any change: `~/Library/Application Support/ShowreelStudio/backups/nuit-20261109-011222`.

## Phase 0 (documentation): done

- **Done:** the "One command to verify" section of `CLAUDE.md` is the text of the last report, as it was. Item 1 of "Open work" is the shortened text, as it was. `docs/phases-done.md` holds the old paragraphs of item 1, one per phase (13 entries), each followed by a line naming the kit files where its rules live.
- **Checked:** the rest of `CLAUDE.md` is byte for byte unchanged (compared before and after in the script that wrote it). All 13 old paragraphs are in `phases-done.md` at the start (first 60 characters of each) and every word of the old item 1 is there except the words of its last sentences ("next W4... Later: ... Stop after each phase"), which are in the new item 1 in the validated form. `tools/verify.sh --fast`: exit 0 in 12 s.
- **Deviation:** phase X had no paragraph in the old item 1, so `phases-done.md` has none for it ("nothing else" was the rule), although the short list says X is archived there. The "Rules in ShowreelKit" line under each paragraph is the only text added to the old paragraphs, as asked ("with the kit file where the rules live"). The old paragraphs are kept as they were, so some are out of date (for example W1 still says "Look elements" in the library).
- **To check by hand:** read `CLAUDE.md` and `docs/phases-done.md` once.

## Phase Q3: Ask Clap and the history in Clap

**Statut : faite.**

Fait :
- L'onglet Clap de l'inspecteur s'intitule « Ask Clap » (`ClapMark.title`), avec une icône unique (`ClapMark.symbol`) dans l'onglet, l'en-tête de conversation, les cartes d'opération et l'écran « Clap is off ».
- Sélecteur en haut de l'onglet : Conversation, Mémoire, Séances, Journal (`ClapSection`, `AskClapPane`, `ClapHistoryPane`). Les trois vues (`WhatClapKnows`, `SessionsList`, `JournalList`) sont reprises telles quelles.
- Onglet History retiré des réglages du projet (restent Project et Look). `HistoryPanel` supprimé.
- Textes visibles « copilot » remplacés par Clap / Ask Clap dans l'interface ; `addendum.md` mis à jour (l'onglet). Ligne ajoutée dans `docs/ux-notes.md` (section Application).
- Test `MemoryTests` mis à jour pour le nouvel emplacement (il vérifie aussi l'absence de l'entrée History dans les réglages).

Vérifié :
- `tools/verify.sh` complet : OK (17 s).
- `tools/rebuild-app.sh` de bout en bout avec la garde par contenu : **passe**, 46,7 s, app relancée (pid 82260), selftest et bundle OK.
- `swift test` deux fois de suite : 336 tests, 0 échec chaque fois (~29 s). Aucun test instable.

Non vérifié (à voir à l'œil) :
- Rendu de l'onglet Ask Clap (icône, sélecteur à quatre segments, largeur du panneau).
- Clic sur une ligne du journal : ouvre bien l'élément ; filtres, ajout/modification/suppression de mémoire, Confirm, Make current dans le nouvel emplacement.
- Réglages du projet : plus que Project et Look.

Écarts :
- L'icône `movieclapper` exige macOS 14 (minimum du projet : 13). Choix : `#available(macOS 14, *)` donne `movieclapper`, sinon `wand.and.stars`.
- Libellés du sélecteur en français (Mémoire, Séances) comme demandé, alors que le reste de l'interface est en anglais.
- Commentaires de code et textes internes de `ChatModel` qui disent encore « copilot » laissés tels quels (hors interface).

## Phase Q2: scene states (WIP, Validated, Locked)

**Statut : faite.**

Fait (règles dans ShowreelKit, vues = dessin seulement) :
- `SceneState` (wip, validated, locked, ditched) dans `SceneStates.swift`. Le mot est stocké dans `status`. Révision de format 1 → 2.
- Migration sans perte : `ok` → Validated, `open` et `modify` → WIP (la note du modify reste ; « à modifier » = WIP avec une note, `toModify`). Lue à tout décodage (fichier, phase A, export de la skill, scène construite en code) ; « Update project » liste le changement, sauvegarde le fichier tel quel, puis écrit les nouveaux mots. Clés inconnues conservées. Un mot inconnu est gardé et compte comme WIP. Le skill n'a pas été modifié (l'export lit `open`/`ditched` : toujours lisible).
- Verrou : un seul point de contrôle dans `ProjectStore.plan()` (donc pour l'utilisateur, les glisser-déposer et les outils de Clap). Refusés avec « S02 is locked: unlock it first » : contenu, texte, durée, note, nom, archivage, ditch, liens de ressources, surcharges de look, étirement du bord dans la bande, déplacement de coupe, dépôt (aussi les fichiers déposés : rien n'est ajouté aux ressources). Autorisés : déplacer la scène dans le montage, l'allumer/l'éteindre, les transitions, et le déverrouillage. Le ripple ne change que les débuts, jamais la durée d'une scène verrouillée. Une ressource liée ne crée pas d'élément dans une scène verrouillée. Le ré-import d'un storyboard.md ne réécrit pas une scène verrouillée (et ne la ditch pas si la ligne a disparu, et un tableau ne verrouille jamais).
- Opération typée `sceneLock(ids, locked)` : une carte avant/après, annulable en une étape, journalisée (`sceneLock`), jamais implicite. Seule une scène Validated se verrouille (« un verrou ne valide jamais ») ; déverrouiller redonne Validated. « Lock all validated » = une carte, un undo.
- Pastille : une icône par état (WIP pointillé, ou crayon orange si une note demande une modification ; coche verte ; cadenas) avec info-bulle ; un clic ouvre un petit menu (`SceneStates.choices`, ce qui est impossible dit pourquoi). Mêmes icônes dans la liste des scènes, la bande (reel), l'en-tête de l'inspecteur et la liste du storyboard. Le bloc Review garde OK / MODIFY / DITCH (MODIFY exige une note), ajoute l'interrupteur « Locked » et dit que Validated n'est pas Locked. Bouton « Lock all validated » dans l'onglet Scenes de la bibliothèque.
- Outils : `lock_scene` ajouté dans `tools.json` et `Tools.swift`, `update_scene`/`add_scene` : enum `wip, validated, ditched`. `addendum.md` : Clap ne tente jamais de modifier une scène verrouillée et propose de la déverrouiller. `capabilities.json` et `process.json` (états du pas Review) mis à jour. Le message de Build signale les scènes verrouillées et dit « Validated or Locked ». `Go` : Validated et Locked comptent comme revues.
- Tests (15 nouveaux, `SceneStateTests`) : migration (fichier, Update project avec sauvegarde, export de la skill), règles du verrou, balayage de tous les types d'opération sur une scène verrouillée (un `switch` exhaustif force à classer toute nouvelle opération), balayage des outils de Clap (refus journalisés, aucune carte montrée), glisser-déposer, ripple, ré-import, message de Build, menu de la pastille. Tests existants adaptés au nouveau vocabulaire ; golden `storyboard.md` ré-enregistré (la colonne Status dit `wip`).

Vérifié :
- `tools/verify.sh` complet : OK (16 s). `tools/rebuild-app.sh` : OK, 48 s, selftest et bundle OK, app relancée (pid 94277).
- `swift test` deux fois de suite : 351 tests, 0 échec chaque fois (~30 s). Aucun test instable.

Non vérifié (à voir à l'œil) :
- Les pastilles et leur menu dans la liste, la bande, l'inspecteur ; l'info-bulle ; l'interrupteur Locked du bloc Review ; le bouton « Lock all validated » (barre de l'onglet Scenes).
- Étirer le bord d'une scène verrouillée dans la bande : le message de refus s'affiche-t-il lisiblement (c'est l'erreur du projet) ? Idem pour un dépôt sur une scène verrouillée (le survol doit indiquer le motif).
- Un projet existant : bannière « Update project » (révision 1 → 2), puis états lus correctement.

Écarts et choix :
- Le changement de look **global** (palette, polices du projet) n'est pas refusé par un verrou : une scène verrouillée qui hérite du look suit le look du projet. Le prompt demandait les « look overrides » seulement. À trancher par le propriétaire (idée possible : le carte d'un changement global signale les scènes verrouillées qui en héritent).
- Seule une scène Validated peut être verrouillée (pas WIP) ; déverrouiller donne Validated. Choix de sûreté (pas de validation silencieuse).
- Le skill n'est pas modifié (aucun bump par ce travail) ; `export_studio.py` écrit toujours `open`/`ditched`, lus comme WIP/Ditched.
- Les arbres de scène n'ont pas de ligne racine : la pastille est sur la ligne de la scène (qui porte l'arbre).
- `tools/check.py` : ajout de `SceneStates.swift` et `SceneStateTests.swift` à la liste des fichiers requis.

## Phase V: build state and player

**Statut : NON construite (étape 0 : la prémisse ne tient pas).** Aucun fichier du code n'a été touché pour V. Ce que le prompt demandait dans ce cas : écrire la constatation et finir.

Constatations de l'étape 0, lues dans le code :
1. **Peut-on réassembler `main.js` sans IA à partir de modules de scène existants ? Non, pas aujourd'hui.** Les modules de scène ne sont pas des fichiers : ce sont les propriétés d'un seul objet `MODULES` écrit par l'IA dans un `main.js` unique (`engine/main.film.template.js`, `references/engine.md` : « film layer, optional mode, experimental »). Rien dans le dépôt (ni `build.py`, ni `Film.swift`) ne découpe ni ne recolle `main.js`. Conséquences : « Generate : produit/met à jour le module d'une seule scène » n'a pas de support (l'IA réécrit tout `main.js`, on ne peut pas garantir que les autres modules restent identiques), et « empreinte du module de chaque scène » n'a pas de module à empreinter.
2. **Ce qui existe déjà et marche sans IA :** réécrire `film.json` (ordre, débuts, durées, transitions : `Film.write`) puis relancer `build.py` (qui l'inline en `SR.data.film`), le harnais et `smoke_player.js` sur le `main.js` existant. Cela couvre ordre, transitions, durées, musique (grille) pour les scènes qui ont déjà un module. Limite dure : `SRF.fromData` **lance une erreur** (« no scene module for S0x ») si une scène du film n'a pas de module : une scène « non générée » bloque l'assemblage, elle ne se dégrade pas.
3. **Durée d'une scène étirée ou coupée :** un module dessine en temps local `lt` (secondes) ; étirée, la scène garde son dernier état (`clamp(lt / d)` tient) ; coupée plus court que son animation, l'animation est tronquée. `c.u` (0..1) existe mais les modules écrits par l'IA ne sont pas tenus de l'utiliser. Donc une durée qui change n'exige pas techniquement de régénérer, mais change ce qu'on voit (cohérent avec « durée = entrée de Generate »).
4. **Transition : elle chevauche les scènes, elle ne s'ajoute pas** (`film.js` dessine sortante et entrante ensemble ; la durée du film ne change pas). Règle déjà en place : durée par défaut = au plus la moitié de la plus courte des deux scènes, et la vérification `reel.transition-length` échoue si une transition dépasse ses scènes (testée dans `FilmTests`).

Pourquoi je n'ai pas construit une version réduite : V est décrit comme un tout (deux opérations, empreintes par scène, lecteur lié à l'état, bouton « Générer N scènes »). Sa moitié « Generate par scène » exige de changer le format de sortie de la skill (modules en fichiers, assembleur déterministe dans `scripts/`, `build-guide`, gabarit, prompt, evals), donc `showreel-director/**`, une version à publier et une décision de portabilité vers d'autres hôtes. C'est une décision d'architecture du propriétaire, pas un détail à improviser de nuit.

Options pour le propriétaire (je recommande la 2) :
1. **V réduit, sans changer la skill :** « Assembler » = `film.json` + `build.py` + checks sur le `main.js` existant, résultat et empreintes d'entrée dans `.studio/build.json` (état du film : jamais assemblé / à jour / périmé ; scènes : sans module / à jour / périmées d'après les empreintes enregistrées à la dernière génération). « Générer » reste la génération de toute la version, mais ne propose que les scènes dont les entrées ont changé et n'écrase pas les autres modules. Pas de garantie byte pour byte des modules non touchés.
2. **Modules en fichiers (changement de la skill) :** l'IA écrit `vN/scenes/S01.js`… ; un assembleur sans IA (nouveau script de la skill, appelé par `build.py`) fabrique `main.js` ; « Générer » ne réécrit qu'un fichier ; les empreintes sont celles des fichiers. Donne exactement le V du prompt. Demande un bump de la skill et la mise à jour de `portability.md`/`capabilities.json` ensemble.
3. Laisser le build tel quel et ne montrer que l'état du film (périmé ou non) sans lecteur lié.

Ligne ajoutée dans `docs/ideas.md` (option 2).

À faire à la main : choisir une option avant de redemander V.

## End of the night

- **Phases :** 0 faite, Q3 faite, Q2 faite, V non construite (constatation ci-dessus).
- **bump.py :** non lancé (aucun fichier de `showreel-director/**` n'a changé ; empreinte de la skill identique du début à la fin : 223d06a5d3d5).
- **Tests instables :** aucun vu (deux passages de `swift test` après Q3 et après Q2, 336 puis 351 tests, 0 échec).
- **Durées mesurées :** `tools/verify.sh` complet 15 à 20 s ; `tools/rebuild-app.sh` 46,7 s (Q3, premier passage de bout en bout avec la garde par contenu : passe) et 48 s (Q2) ; `swift test` ~30 s.
- **Écarts au prompt :** voir chaque phase (icône de repli sous macOS 13 ; libellés français du sélecteur ; look global non verrouillé ; seule une scène Validated se verrouille ; V non construite).
- **Aucune commande git, aucun osascript, aucune installation de paquet, ROADMAP.md non touché ; CLAUDE.md modifié seulement par la phase 0.**
