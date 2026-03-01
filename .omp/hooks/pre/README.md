# .omp/hooks/pre/

This directory is where omp loads pre-tool-call hooks from at startup.

The files here are **symlinks** managed by `hooks/install.sh`. Do not edit
them directly — edit the source files in `hooks/global/` instead.

To add or remove hooks:
1. Edit `hooks.enabled` in `config.yml`
2. Run `bash hooks/install.sh`

To write a new hook, see `hooks/README.md` for the full authoring guide.
