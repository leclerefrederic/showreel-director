# DS3b: what DS3 left undone (app 0.19.1, skill untouched)

## Built

1. **One text field style.** `ThemedTextFieldStyle` now fills the pane, takes its height and radius from `FormLayout`, shows an accent focus ring, an error state (`.fieldError(message)`: danger ring and the message next to the field) and a dimmed disabled state (`disabledWithReason` still gives the reason). **23 fields converted** from the native rounded border (ContentViews 3, EditorViews 1, DragDropViews 1, HistoryViews 4, LookViews 2, ProjectFormViews 1, PickerViews 1, ResourceViews 3, ReelViews 5, StoryboardViews 1, WorkspaceViews 1). The Duration `StepperField` has the same height, radius and ring. Placeholders: the scene's four multi-line fields got real examples.
   **Left on the native style, with the reason:** the Settings window (5 fields) and the package and new-project sheets (4): native `Form` rows with their own label column; the Clap composer (a multi-line input with its own chrome); the file editor's text view (a code editor); the inline name editors (`.plain` by design).
2. **Growing multi-line fields.** `GrowingTextEditor` reads `FormLayout.areaLines` (2 to 8 lines) and hides the scroll indicator unless the text exceeds the limit. Used for the scene's Feeling, Passage, note and text fields.
3. **Stepper arrow keys on macOS 13.** `StepperKeys`: a local key-down monitor that lives only while the field has focus, maps the key with the pure `NumericField.keyStep` (Up, Down; Option fine, Shift coarse) and consumes it. **Verified by a test of the mapping only; the behaviour (the monitor, the focus hand-over) is not verified.**
4. **Buttons by role** (before: default grey or native bordered; after):
   Primary: BuildViews Connect AI; NewProjectViews Create; PackageViews Add to the library; SetupView Install missing; ChatView Confirm, Accept.
   Secondary: BuildViews Show them, Show in Finder; EditorViews Load the disk version, Keep mine, Restore this version; FilmStateViews Fix this scene; InspectorViews Apply this palette to the scene, Open the project settings; LookViews Use these moods, Use this palette, Use as the effects pack, plus the other former `.bordered`; NewProjectViews Choose...; PackageViews Show in Finder, Open a .studiopack; ReactionViews Refuse all; ResourceViews Decline, Accept the risk, Replace the file...; ReelViews Recompute the grid; SetupView Check again; ChatView Refuse; WizardStartViews Fill the form myself; the 7 `.bordered` (Look 4, Block, Picker, Inspector).
   Quiet: InspectorViews Back to the viewer (2); ProjectLifecycleViews Not now; SetupView Continue without; LibraryView Remove from Library.
   **Not changed (multi-line buttons my script could not edit safely):** BuildViews Test it again, FontStateViews Add the font files, LookViews Use this background, PackageViews Export a .studiopack file, ReactionViews Cancel build (meant as destructive), ReelViews Revert to a cut, SettingsView Save (meant as primary), LibraryView Locate and Remove (row buttons). Also left: the buttons inside menus, alerts, context menus and the strip's toolbar (DS2's area), which keep the native look.

## Tests

`DS3bTests` (5): height and radius from `FormLayout`; no native field style or own height or radius in these areas; the growth rule is read by the editor and used by the scene form; the key mapping; no `.bordered` left in four files. No existing test changed.

## Verified, not verified

Verified: the complete `tools/verify.sh` and `tools/rebuild-app.sh` (see the end of the session). **Not verified: anything drawn or typed**: the focus ring, the error state, the growth and the scroll bar, the key monitor, the roles' look.

## To check by hand

Every kind of text field at several pane widths (fill, focus ring, error, disabled with its reason); a two-line scene field with no empty scroll track, then a long text growing and scrolling; the Duration field with Up and Down, Option and Shift (also check Up and Down do not move the cursor in other fields); the buttons by role in the inspector, the project form, Settings and the Build view.
