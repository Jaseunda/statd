## Description

<!-- Provide a brief summary of the changes and what problem they solve. -->

## Motivation & Context

<!-- Explain why this change is needed. If this fixes an open issue or adds support for specific environments (e.g. Proxmox VE, ZFS, multi-core servers, macOS, Termux), mention it here. -->

## Classification

- [ ] **Core / Built-in** (`lib/` or `statd`): Universal metric, zero external CLI dependencies, reads directly from kernel (`/proc`, `sysctl`).
- [ ] **Plugin** (`plugins/<name>/`): Specialized hypervisor, filesystem, daemon, or tool (e.g. Proxmox `pvesm`, ZFS pools, Docker, themes).

## Type of Change

- [ ] `feat`: New feature, sensor, or theme
- [ ] `fix`: Bug fix or edge-case handling
- [ ] `perf`: Performance optimization (e.g. zero forks, reduced subshells)
- [ ] `docs`: Documentation update
- [ ] `refactor`: Code reorganization without functional changes

## Platforms Tested

- [ ] Linux / Proxmox VE (Debian)
- [ ] Linux (Ubuntu / Fedora / Arch)
- [ ] macOS (Apple Silicon / Intel)
- [ ] Android / Termux
- [ ] Other: 

## Verification Checklist

- [ ] Ran `make check` and all files passed syntax checks
- [ ] Ran `./bundle.sh` if modifying `lib/*` or `statd` to update `dist/statd`
- [ ] Ensured zero external process forks in the hot rendering loop
- [ ] Verified clean terminal output without cursor glitches or arithmetic warnings
