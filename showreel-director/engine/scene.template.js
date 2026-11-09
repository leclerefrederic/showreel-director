/* Scene file: scenes/<ID>.js, one per scene of film.json, named by the scene ID (S01.js). The file is the BODY of a function: scripts/assemble.py wraps it in its own scope
   and puts it into main.js, so helpers declared here are private to this scene and never collide with another scene's. It must end with a return of the render function.
   Contract: references/engine.md, "Scene files". Everything below is a placeholder: write the scene from the brief, the storyboard and the style sheet. */
const { clamp, ease } = SR;                    // globals of the engine: SR, SRK (kit), SRB (backgrounds, when used); never redeclare these three names

return function render(g, lt, c) {
  // lt: seconds since the start of THIS scene; c.u: 0..1 progress through it; c.SW x c.SH: the stage; c.reduced: reduced motion; c.lang, c.mode, c.sig, c.t
  // draw with lt (never with the clock) and let the last state hold: clamp(lt / duration)
};
