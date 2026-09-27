cask "classiclaunch" do
  version "0.30"
  sha256 "dece4c2dcf05741c620177883ef44ad8b712d5145852f1c27d2549db96c31791"

  url "https://github.com/gxh259/classiclaunch/releases/download/v#{version}/ClassicLaunchpad-#{version}-universal.zip"
  name "启动台"
  desc "Classic full-screen macOS application launcher"
  homepage "https://github.com/gxh259/classiclaunch"

  depends_on macos: :sequoia

  app "启动台安装包/启动台.app"

  uninstall quit: "local.codex.classiclaunchpad"

  zap trash: [
    "~/Library/Application Support/ClassicLaunchpad",
    "~/Library/Caches/local.codex.classiclaunchpad",
    "~/Library/LaunchAgents/local.codex.classiclaunchpad.login.plist",
    "~/Library/Preferences/local.codex.classiclaunchpad.plist",
    "~/Library/Saved Application State/local.codex.classiclaunchpad.savedState",
  ]
end
