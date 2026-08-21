# ArtifactBridge Homebrew tap

This public tap distributes the signed and notarized ArtifactBridge Tray app
for macOS.

After the first compatible stable release is published, install it with:

```sh
brew install --cask omnim-ai/tap/artifactbridge
```

The disk image (DMG) remains the primary download on the ArtifactBridge web
site. This tap is an alternative installation method.

## Release process

The private ArtifactBridge source repository sends only an immutable
`tray-v<version>` tag through a repository-scoped GitHub App. The update
workflow in this repository then:

1. downloads the release identity, checksums, and universal DMG from the
   public ArtifactBridge release proxy;
2. verifies the stable release identity and every downloaded digest;
3. generates `Casks/artifactbridge.rb`;
4. runs the repository contract checks; and
5. pushes an immutable version branch.

The repository-scoped GitHub App then opens the pull request from the private
ArtifactBridge release workflow. The App credential stays in the private
source repository.

The tap does not contain a Cask until the first stable release with the
`macos-homebrew` ownership contract is available. Version 0.5.14 and earlier
must not be published through this tap.

See [CONTRIBUTING.md](CONTRIBUTING.md) for validation commands.
