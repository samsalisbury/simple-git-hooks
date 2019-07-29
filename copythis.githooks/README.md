# .githooks

Simple, low-dependency git hook management using only bash.

## Usage

Place executable scripts to handle git hooks in `./<hook-name>/`.
Run `./install` to set this repo up to use those hooks.
After adding or removing a `<hook-name>/` directory, re-run `./install`.

WARNING: The `./install` script takes full control of `.git/hooks`,
and may delete hooks you have in there currently.
If you have any existing hooks that you want to preserve, move them
to `./<hook-name>/`. 

## What are these files?

Each subdirectory of this .githooks directory is named after one of the
known git client-side hooks.
Each executable file inside one of these directories is a handler script
to be run for the git hook named by the directory.

The `./install` script sets up a minimal hook inside this repo's .git/hooks
directory, which in turn uses the `./run.bash` script here to find and run
all of the required scripts.

## What are the handlers?

The handlers in `<hook-name>/` directories can be any executable file,
they are executed to handle the correspondingly named git hook.
They will inherit the standard environment
variables and arguments passed to the main hook, as documented in
https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks

Each hook may exit with any status code relevant to that hook.
The first handler that exits with a non-zero exit code causes the hook
to exit with that code. For example in the case of a `pre-commit` hook,
this will cancel the commit.

## Notes on handler implementation

Handlers should not print any output if there are no relevant changes
staged. They should print output if there are relevant changes staged.
They should perform the cheapest checks first, and save any heavier
checks for later, so they are only run if absolutely necessary.
