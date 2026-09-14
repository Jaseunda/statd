# Contributing to statd

statd is a pure Bash project. Contributions should stay that way — no
compiled binaries, no interpreted runtimes, no external package managers
required to run the tool.

## Before You Start

- Run `make check` to confirm all files pass a bash syntax check
- Keep each `lib/` file focused on one concern
- Avoid adding dependencies beyond standard POSIX tools
- Test on at least the platform you are adding support for

## File Layout

```
statd                   Entry point. Sources lib/, holds the main loop.
lib/colors.sh           Terminal color variables and pct_color()
lib/render.sh           Gradient bars, row builder, human-readable sizes
lib/sensors_linux.sh    Linux sensor implementations (_linux_* functions)
lib/sensors_macos.sh    macOS sensor implementations (_macos_* functions)
lib/sensors.sh          OS detection, NCPU, get_* dispatcher functions
lib/llm.sh              llama.cpp metrics and process helpers
Formula/statd.rb        Homebrew formula
Makefile                install / uninstall / check
install.sh              One-shot installer script
```

## Adding a New Platform

1. Create `lib/sensors_<platform>.sh` with `_<platform>_<sensor>()` functions
   matching the signatures of the existing Linux and macOS implementations.
2. Source the new file in `statd`, after the existing platform sources.
3. Add a dispatcher branch for the new platform in each relevant
   `get_<sensor>()` function inside `lib/sensors.sh`.
4. Run `make check` — all files must pass.
5. Document the platform in `README.md` under Platform Notes.

## Adding or Changing a Sensor

- Add the implementation to both `lib/sensors_linux.sh` and
  `lib/sensors_macos.sh` (or just the relevant one, gracefully returning
  empty/`--` on unsupported platforms).
- Add or update the dispatcher in `lib/sensors.sh`.
- If the sensor requires a new state variable, declare it in `statd` near
  the existing state block.

## Code Style

- Use `local` for all variables inside functions.
- Validate numeric inputs with `[[ "$var" =~ ^[0-9]+$ ]]` before arithmetic.
- Prefer `awk` over `bc` or Python for floating-point formatting.
- Avoid subshell forks inside the hot path (the inner render loop).
- Do not use `echo` — use `printf` throughout.
- No tabs for indentation: 4 spaces.

## Pull Requests

- Open an issue first for large changes so we can agree on direction.
- Keep each PR focused on a single concern.
- Include a brief description of what platform or use case you tested on.
- The PR title should complete the sentence: "This PR..."

## Reporting Issues

Include:
- OS and kernel version (`uname -a`)
- Bash version (`bash --version`)
- What you expected to see
- What you actually saw (paste the output or describe the behavior)

## License

By contributing you agree that your changes will be licensed under the
MIT License. See [LICENSE](LICENSE).
