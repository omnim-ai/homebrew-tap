cask "artifactbridge" do
  version "0.5.21"
  sha256 "6723365806bc70f6d987b56f2755962a4a45ccfa1e341568cd39d199a7f1dcbe"

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

  auto_updates true
  depends_on :macos

  app "ArtifactBridge Tray.app"
  binary "#{appdir}/ArtifactBridge Tray.app/Contents/MacOS/artifactbridge",
         target: "artifactbridge"

  postflight do
    system_command "#{appdir}/ArtifactBridge Tray.app/Contents/MacOS/artifactbridge",
                   args:         [
                     "installation",
                     "register-homebrew-cask",
                     "--brew-prefix",
                     HOMEBREW_PREFIX,
                     "--json",
                   ],
                   must_succeed: true
  end

  uninstall_preflight do
    system_command "#{appdir}/ArtifactBridge Tray.app/Contents/MacOS/artifactbridge",
                   args:         [
                     "installation",
                     "unregister-homebrew-cask",
                     "--brew-prefix",
                     HOMEBREW_PREFIX,
                     "--json",
                   ],
                   must_succeed: true
  end

  uninstall quit: "com.artifactbridge.tray"
end
