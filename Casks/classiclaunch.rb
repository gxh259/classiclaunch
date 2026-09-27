cask "classiclaunch" do
  version "0.29"
  sha256 "80fd57394d11820b83dbf35752e6708a2c0eac8dce21a78b77dbb59161f5ce2a"

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
