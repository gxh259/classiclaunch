cask "classiclaunch" do
  version "0.34"
  sha256 "dbae4fa479f02eeee937d7f9af90c5b781c03ec8726531289779e47ef68e7d9a"

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
