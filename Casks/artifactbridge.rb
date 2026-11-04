cask "artifactbridge" do
  version "0.5.198"
  sha256 "77f58d316aa159eff29d50765c14e52f9b817f55533e55c76c8577f04f265642"

  url "https://app.artifactbridge.com/tray/releases/download/tray-v#{version}/ArtifactBridge-Tray-macos-universal.dmg"
  name "ArtifactBridge"
  desc "Share governed documents with coding agents"
  homepage "https://artifactbridge.com/"

  livecheck do
    url "https://app.artifactbridge.com/tray/releases/latest/download/VERSION"
    strategy :page_match do |page|
      page.scan(/^\s*(\d+(?:\.\d+){2})\s*$/).flatten
    end
  end

  depends_on :macos

  app "ArtifactBridge.app"
  binary "#{appdir}/ArtifactBridge.app/Contents/MacOS/artifactbridge",
         target: "artifactbridge"

  postflight_steps do
    run "ArtifactBridge.app/Contents/MacOS/artifactbridge",
        args:           [
          "installation",
          "register-homebrew-cask",
          "--brew-prefix",
          "{{HOMEBREW_PREFIX}}",
          "--json",
        ],
        base:           :appdir,
        writable_paths: ["~/.artifactbridge"],
        must_succeed:   true
  end

  uninstall_preflight_steps do
    run "ArtifactBridge.app/Contents/MacOS/artifactbridge",
        args:           [
          "installation",
          "unregister-homebrew-cask",
          "--brew-prefix",
          "{{HOMEBREW_PREFIX}}",
          "--json",
        ],
        base:           :appdir,
        writable_paths: ["~/.artifactbridge"],
        must_succeed:   true
  end

  uninstall quit: "com.artifactbridge.tray"
end
