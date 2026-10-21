cask "artifactbridge" do
  version "0.5.159"
  sha256 "a6cd5c7797409f3a33d1158f7fc832d3217da8a6bf9fbd6ca1d9bc2fb840b53f"

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
