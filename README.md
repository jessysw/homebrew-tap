# Contitext Homebrew tap

Project-maintained Homebrew packages for [Contitext](https://github.com/jessysw/contitext).

```sh
brew install jessysw/tap/contitext
contitext --version
```

This installs the CLI and native MCP runtime, **not a configured service or database**.
Supply PostgreSQL 16+ and follow the [installation guide](https://github.com/jessysw/contitext/blob/main/docs/installation.md).
The source formula builds its pinned Python dependencies; the first installation can take several minutes.

```sh
brew update
brew upgrade contitext
brew test contitext
brew uninstall contitext
```

Configuration, credentials and database files belong outside the Homebrew prefix.
Installing, upgrading or uninstalling this formula does not edit agent settings,
start services, run migrations or delete user data. Back up your database before
running any separately requested application migration.

For agent configuration use the stable absolute executable
`$(brew --prefix)/opt/contitext/bin/contitext`, not a versioned Cellar path.
Agent instructions and the optional installer are included under
`$(brew --prefix)/opt/contitext/share/contitext`.

Stable releases generate a checksummed formula update PR. macOS ARM, macOS Intel
and Linux installation checks run before automated formula updates are merged.
This tap is maintained by the project; it is not part of Homebrew/core.

Licensed under Apache-2.0.
