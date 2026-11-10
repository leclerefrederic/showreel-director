---
type: ux
status: current
phase: 
date: 2026-11-10
summary: "Owner remarks and decisions on Resources, starting with the app asking before a Build when a Look font has no file."
tags:
  - ux
---

Part of [[ux-notes]].

# Resources

- Decision (owner, C1, 2026-11-09): when a Build or an Assemble starts and a Look font has no file, the app asks first (fonts, source, licence, size; Download and continue, Continue with a system font, Cancel). Nothing is downloaded without the yes; the orange Fonts step stays when files are missing.

- **Built in R1 (2026-11-09).** Groups by type (Images, Sounds, Music, Fonts, Other) then by state with folding remembered per project, the preview of the selected resource in the centre (image, sound or music with its tags, cover and a small player, font specimen), tags (stored in `showreel.json`; "placeholder" is the manifest status shown as a tag), a derived "Used in" with clickable scene tags, the four states, Needs attention from automatic checks with the rights question or an accepted risk, and a flagged file hidden from Clap. The AI analysis of resources at adding (R2) is not built. The notes below are the owner's remarks that led to it.

- Group the resources by type, then by status.
- Types: Images, Sounds, Music.
- The central zone is the preview of the selected resource.
- For a music file the centre shows its metadata, the cover image when the metadata holds one, and a simple player (play, pause, scrub).
- Resources can carry tags (for example an image can be a logo or a wallpaper), and the list can be filtered by tag.
- Decided: tags live in `showreel.json` (app mechanics, the skill's manifest format is untouched); Music = `audio` tracks, Sounds = `sfx` and `voice`.
- Resource inspector, seen on screen: "Used in scenes" must not be a free text field. It is derived: show a tag per scene that uses the resource (clickable, selects the scene); linking is done from the scene.
- Simplified resource states (owner's direction, refined): a resource is used or it is not. The user sees four things only: **Available** (in the library, approved because the user added it, not used by any scene yet), **Used in S01, S07** (one clickable tag per scene), **Proposal** (only when the AI analysed something and suggests it: a read-only note giving the AI's reason, and two buttons, Approve or Decline; approving makes the resource approved and links it to the scene), and **Needs attention** (see below). A declined proposal is kept out of sight (collapsed "Declined") so the AI does not propose it again.
- Safety stays, but automatic: the app flags a file by itself (name suggests personal or confidential data, resolution too low, heavy file, rights or consent not confirmed, font licence forbids embedding) and marks it **Needs attention** with the reason in plain words; it cannot be used until the user fixes it (replace the file) or accepts the risk with a short reason (this is the skill's hold and waiver, kept under the hood). No status dropdown for the user to manage.
- Under the hood the skill's manifest statuses stay: Available and Used = approved, Proposal = proposed, Declined = excluded, Needs attention = hold. Placeholder becomes a tag ("placeholder", listed in the release gate).
- "Licence note" and "Note" fields: drop them as permanent fields. The rights question is asked only when a file is flagged, with a short list (own work, supplied by the client, licensed, free licence, unknown; unknown puts it on Needs attention) and an optional detail; a note appears only on Needs attention or when the user adds one.
- When a file is added: (1) automatic checks run at once, without AI and without a key (type, resolution, weight, personal-data hints in the name, copyright fields in the metadata, font embedding flag); a flagged file goes straight to Needs attention. (2) AI analysis is a second, optional step for what the rules cannot see (a watermark, a recognisable person, a third-party logo, a screenshot with personal data). It runs by default for files that passed the automatic checks, once the project has the owner's consent for it (a project setting, asked the first time a key is used); a file flagged by the automatic checks is never sent to the AI. The AI can only raise a suspicion, as a Proposal or a Needs attention reason: it cannot know the legal licence of a file, so the decision stays with the user.
- Staging is physical: a file that needs attention stays in `assets/source/` (never in `assets/prepared/`), is left out of the AI's prompt and tools (the copilot cannot read it and Build refuses it, as `build.py` already does for held files). The AI never uses it, whatever it concludes.
