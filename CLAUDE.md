# CLAUDE.md — Snake (Godot test project)

## Project
A small, disposable test project to dial in the Claude Code + Godot MCP
vibe-coding workflow. The goal is a working classic Snake clone — not a
polished game. Keep it simple and finish it.

## Tech stack
- Godot 4.x, **GDScript only** (no C#)
- 2D, grid-based movement
- Godot MCP server (`Coding-Solo/godot-mcp`) is connected — use it to
  inspect/run the project rather than guessing at scene state

## Grid & resolution (set once — ask before changing)
- Grid cell size: 16x16 px
- Base resolution: a clean multiple of the cell size (e.g. 320x192 = 20x12 cells)
- Stretch Mode: `viewport`, Stretch Aspect: `keep`
- Snap 2D Transforms to Pixel: on

## Scope for v1 (don't add beyond this without asking)
- Snake moves on a fixed grid, one direction at a time, no diagonals,
  can't reverse directly into itself
- Eating food grows the tail by one segment
- Hitting a wall or its own tail ends the game
- Simple score display (segments eaten / length)
- Restart on game over
- Explicitly out of scope: menus, multiple levels, difficulty ramp,
  sound/music, save data — cut these to keep it a quick test

## Project structure
- `res://scenes/` — .tscn scene files
- `res://scripts/` — .gd scripts, one per scene/node responsibility
- `res://autoload/` — singletons only if truly needed; ask before adding one

## Working agreement
- Explain the reasoning behind non-trivial code choices, not just the code
- Commit after each working increment, with a descriptive message
- Ask before changing project-wide settings (resolution, input map,
  autoloads) once they're set
- Prefer built-in Godot nodes/signals (Timer, Area2D, input actions) over
  custom frameworks — this project is too small to need one

## How to run/test
- Open the project in Godot and press F5
- Use the Godot MCP tools to inspect scene state / run the project
  directly where possible, rather than asking me to describe it
