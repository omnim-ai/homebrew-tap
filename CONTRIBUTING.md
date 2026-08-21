# Contributing

All Cask changes must use a pull request. Do not edit a published version or
digest in place.

Run the repository checks before a push:

```sh
scripts/test-repository.sh
```

When `Casks/artifactbridge.rb` exists, also run:

```sh
brew tap omnim-ai/tap "$(pwd)"
brew style omnim-ai/tap/artifactbridge
brew audit --cask --strict omnim-ai/tap/artifactbridge
brew livecheck --cask omnim-ai/tap/artifactbridge
```

The pull-request workflow runs the Cask tests on Apple Silicon and Intel macOS
runners. It also installs the Cask and verifies its signature, notarization,
release identity, Homebrew ownership record, and uninstall behavior.
