cask "artifactbridge" do
  version "0.5.29"
  sha256 "d4ac34377c83483501fc08baa8d586b63593471c90d6f44b0f931df97851767d"

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
