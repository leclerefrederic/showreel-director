/* Entry of the Three.js bundle (engine/gl/three-bundle.js). The bundle is MIT licensed (the licence block stays at its end) and is inlined by build.py in its own
   script (id sr-gl) only when main.js uses SR3D. It exposes window.T3 = {THREE, EffectComposer, RenderPass, UnrealBloomPass, ShaderPass}.
   Rebuild (maintainer, needs network; the current file was produced with the full namespace import below):
     npm install three esbuild      (in a scratch folder)
     npx esbuild three-entry.js --bundle --minify --format=iife --outfile=three-bundle.js
   Named imports instead of `* as THREE` let esbuild drop what is unused (expected 250 to 350 KB, not tried here): list every THREE symbol that
   engine/gl/scene3d.js and the scenes use, then check with `node scripts/test_sr3d.js`. */
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
window.T3 = { THREE, EffectComposer, RenderPass, UnrealBloomPass, ShaderPass };
