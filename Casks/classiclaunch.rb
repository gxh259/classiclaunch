cask "classiclaunch" do
  version "0.47"
  sha256 "aa5922c48ef59fe7afdf86e9396b53bc05df350c6e334c18b6fe6b9621e6965a"

  url "https://github.com/gxh259/classiclaunch/releases/download/v#{version}/ClassicLaunchpad-#{version}-universal.dmg"
  name "启动台"
  desc "Classic full-screen macOS application launcher"
  homepage "https://github.com/gxh259/classiclaunch"

  depends_on macos: :sequoia

  app "启动台.app"

  uninstall quit: "local.codex.classiclaunchpad"

  zap trash: [
    "~/Library/Application Support/ClassicLaunchpad",
    "~/Library/Caches/local.codex.classiclaunchpad",
    "~/Library/LaunchAgents/local.codex.classiclaunchpad.login.plist",
    "~/Library/Preferences/local.codex.classiclaunchpad.plist",
    "~/Library/Saved Application State/local.codex.classiclaunchpad.savedState",
  ]
end
