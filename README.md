# dotfiles-lib

[![Tests](https://github.com/colajam93/dotfiles-lib/actions/workflows/tests.yml/badge.svg)](https://github.com/colajam93/dotfiles-lib/actions/workflows/tests.yml)

Shell helpers for managing dotfiles.

## Symlinks

Requires Bash and GNU coreutils. Register the links for all selected categories
in the same shell, then apply the plan:

```bash
source "$DOTFILES_ROOT/external/dotfiles-lib/dotfiles-lib.sh"

dfl_link_reset
dfl_link_add "$DOTFILES_ROOT/core/gitconfig" "$HOME/.gitconfig"
dfl_link_add "$DOTFILES_ROOT/core/gitignore" "$HOME/.config/git/ignore"
dfl_link_apply
```

Category scripts such as `core/links.sh` can be sourced to register their links
with `dfl_link_add SOURCE DESTINATION`. Registration does not change the
filesystem. Relative paths are anchored to the working directory at registration;
the destination must name the link itself, without a trailing slash.

`dfl_link_check` validates the entire plan without creating files.
To inspect the planned changes, call `dfl_link_preview` after registration:

```bash
dfl_link_preview
# create /home/user/.gitconfig -> /path/to/dotfiles/core/gitconfig
# skip /home/user/.config/git/ignore -> /path/to/dotfiles/core/gitignore
```

Preview validates the entire plan before printing anything to standard output.
Each line shows `create` or `skip`, followed by the destination and source.
Paths use Bash shell escaping so spaces and newlines remain unambiguous. Preview
neither changes the filesystem nor clears the plan; an empty plan prints nothing.

`dfl_link_apply` always checks the plan again before creating parent directories
and absolute symlinks. Existing symlinks to the same target are kept. Missing
sources, existing destination files or directories, conflicting or broken links,
and duplicate or overlapping destinations cause validation to fail. Existing
parent directory symlinks are followed; broken parent links are rejected.

The plan remains registered after applying it. Use `dfl_link_reset` to start a
new plan. Keep the source checkout or extracted archive in place while its links
are in use. Applying a plan does not require Git or network access.

Application stops on an I/O error and returns nonzero. Changes already made are
not rolled back, and validation does not protect against concurrent filesystem
changes. Existing copies are not automatically replaced or migrated.

## License

MIT
