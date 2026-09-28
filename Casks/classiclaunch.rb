cask "classiclaunch" do
  version "0.32"
  sha256 "38b2c2d5df8c62b333e965f5190f1b88e7e8bd00c0058a7d6ff225757b791fe1"

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
