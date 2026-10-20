# Browser and Windows export plan

The project chooses the Compatibility renderer and GDScript to keep Godot 4 web export viable, but **it has not been exported or tested in a browser**. Godot 4 web export targets WebGL 2 and WebAssembly; more complex shading/features may not translate from desktop.

## Acceptance workflow

1. Install official matching export templates from Godot's Editor menu.
2. Add an HTML5 export preset in Godot's Export dialog with only supported options.
3. Export `index.html` and its related files to a clean `build/web/` directory.
4. Serve the folder via local HTTP (`python -m http.server 8000 --directory build/web`), not opening the HTML directly from `file://`.
5. Verify controls, camera, materials, sound, game state and fullscreen/resizing; inspect browser developer console.
6. Test Chromium and Firefox desktop; evaluate mobile browser/touch support as a separate milestone.
7. Record actual results in `docs/TEST_RESULTS.md` and performance numbers. Do not assume mobile or portrait compatibility merely because code compiles.

For Steam/Windows use a Windows Desktop export template, validate `exe` and accompanying pack files, then smoke-test on a clean machine when possible.
