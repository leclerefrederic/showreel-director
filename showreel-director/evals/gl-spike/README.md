# 3D layer spike

A two-scene test film for `engine/gl` (`window.SR3D`): a particle field pulled toward a point, an emissive sphere and a soft glow in the first scene, the same kind of field thrown outward with a ring glow in the second, each with one word drawn in 2D over the 3D.
Plain test colours and no wording of any look: it only proves the mechanics. `tools/check.py` builds it, checks that the bundle and `scene3d.js` are inlined only for a reel that names `SR3D`, and runs the harness, which must report no issue and must say that the 3D scenes were not rendered (no WebGL in Node).
`scripts/test_sr3d.js` tests the pure parts (GLSL lint, seeded particle data, camera maths, the inert stage, the graph of Three objects).
Build it by hand: `python3 scripts/build.py evals/gl-spike/v1`, then open `evals/gl-spike/v1/dist/index.html` in a browser to see the 3D (the Node harness cannot).
