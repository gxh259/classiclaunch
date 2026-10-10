# 啟動台（ClassicLaunchpad）

[简体中文](README.md) · **繁體中文** · [English](README.en.md)

以 Swift 和 AppKit 編寫的 macOS 啟動台。提供全螢幕應用程式網格、搜尋、資料夾、翻頁及多種開啟方式，適合希望繼續使用經典啟動台佈局的使用者。目前版本為 **0.38**，建置產物為同時包含 **Apple 晶片（arm64）與 Intel（x86_64）** 的通用應用程式。建議下載 DMG，按兩下即可開啟拖曳安裝視窗。最低部署目標為 macOS 15.0；目前已在 macOS 27.0 / Apple M1 上驗證原生執行，x86_64 自我測試已透過 Rosetta 驗證，尚未在 Intel 實機上驗證執行。

安裝包中的檔案名稱仍為簡體中文，例如 `启动台.app`；以下指令及路徑保留實際名稱，可直接複製使用。

## 功能

- 全螢幕網格與應用程式搜尋；名稱更靠近圖示，橫向間距會依螢幕大小調整；支援拖曳排序、建立及重新命名資料夾、隱藏應用程式和自訂應用程式名稱。
- 可選 5×7、6×8、7×8、7×9 網格佈局，也可在設定中自訂 2–12 列、3–16 欄；舊版儲存的 7×7 會作為自訂佈局保留。可透過滑鼠左鍵左右拖曳、觸控式軌跡板三指橫向滑動、滾輪、方向鍵或固定在頁面底部的圓點切換頁面。
- 從 `/Applications` 掃描應用程式，優先使用符合系統語言的名稱。Finder「實用工具」中的應用程式會歸入「其他」資料夾。可手動重新掃描，也可選用 Dock 啟動台資料庫補充系統應用程式。
- 透過 Dock、選單列、可錄製的全域快速鍵或熱點角落開啟。
- 設定視窗提供淺色、深色、跟隨系統三種主題，以及登入時啟動、顯示或隱藏選單列圖示等選項。介面語言可選跟隨系統、简体中文、繁體中文或 English。
- 點按網格外的背景或按 Escape 關閉啟動台。右鍵選單可開啟、重新命名、隱藏或在 Finder 中顯示應用程式；具有權限的第三方應用程式也可移到垃圾桶。
- 淺色主題使用透明視窗和系統毛玻璃顯示下方桌面，支援動態桌布；深色主題在視窗內模糊桌布。背景與圖示翻頁動畫分層，並隨顯示器尺寸變化調整視窗。
- 設定中提供「完整解除安裝啟動台…」，可移除應用程式、登入時啟動及本機設定；安裝包也包含舊版解除安裝後使用的殘留清理工具。
- 應用程式使用彩色九宮格圖示；重新產生 Finder 讀取的 `.icns`，修正「應用程式」列表可能顯示異常小圖示的問題。

## 建置

需要 macOS、Apple 命令列開發工具（`xcode-select --install`）、Swift 編譯器及 Python 3.10 或更新版本。在儲存庫根目錄執行：

```bash
chmod +x build.sh
./build.sh
```

腳本分別編譯 arm64 和 x86_64，再合併為通用執行檔，於 `dist/` 產生 `启动台.app`、`启动台-通用版.dmg` 及備用的 `启动台-通用版.zip`。首次建置會在 `.build/dmg-tools` 建立 Python 虛擬環境，並安裝 [`dmgbuild`](https://github.com/dmgbuild/dmgbuild) 及固定版本的打包相依套件，需要連線至網路；之後可重複使用。若 `python3` 版本較舊，可使用 `PYTHON_BIN=/path/to/python3 ./build.sh` 指定直譯器。DMG 使用自訂背景、固定圖示位置及 Applications 捷徑。腳本使用本機 macOS SDK 編譯，並對合併後的應用程式進行臨時簽署（ad hoc signing）。此建置尚未經過 Apple 公證。

## 安裝與使用

### 手動安裝

從 [GitHub Releases](https://github.com/gxh259/classiclaunch/releases) 下載通用版 **DMG**。按兩下掛載後，視窗左側顯示啟動台，右側顯示 **Applications** 資料夾，中間有拖曳箭頭。將啟動台拖入右側資料夾，再從 `/Applications` 開啟；安裝完成後，可在 Finder 側邊欄退出「启动台」磁碟映像。視窗下方保留紅色「安裝後若提示無法開啟」提示，以及「隱私權與安全性 → 強制打開」的操作示意圖，並提供安裝說明及舊版殘留清理工具。示意圖以簡體中文顯示。

若已有舊版本，請先完全結束所有正在執行的啟動台（可在「活動監視器」中確認），再拖曳新版並等待複製完成；複製期間不要啟動。若取代時顯示「無法打開」，請確認複製完成、結束殘留的舊程序，然後從 `/Applications/启动台.app` 打開。登入時啟動需要應用程式位於 `/Applications`。也提供備用 ZIP：解壓縮後，將 `启动台.app` 拖到同一資料夾內名為 `应用程序` 的捷徑即可。

### Homebrew 安裝

儲存庫的 [`Casks/classiclaunch.rb`](Casks/classiclaunch.rb) 提供 Homebrew Cask。由於儲存庫名稱為 `classiclaunch`，需要在 `brew tap` 中指定儲存庫網址：

```bash
brew tap gxh259/classiclaunch https://github.com/gxh259/classiclaunch.git
brew install --cask gxh259/classiclaunch/classiclaunch
```

之後可執行 `brew upgrade --cask gxh259/classiclaunch/classiclaunch` 更新，或執行 `brew uninstall --cask gxh259/classiclaunch/classiclaunch` 解除安裝。Homebrew 預設保留使用者設定；若要一併刪除本機設定，可在解除安裝時加上 `--zap`。

### 首次開啟與簽署

本應用程式使用臨時簽署，尚未經過 Apple 公證。確認安裝包來源可信且未遭竄改後，如果 macOS 阻止開啟，請先嘗試開啟一次應用程式，再進入 **「系統設定 > 隱私權與安全性」**，向下捲動並點按 **「強制打開」**，依系統提示確認。詳見 [Apple 官方操作說明](https://support.apple.com/zh-tw/102445)。DMG 中保留了此流程的示意圖，圖中的按鈕僅供示意，需要在系統設定中操作。

確認下載來源可信後，若仍被隔離標記阻擋，可在終端機執行：

```bash
sudo xattr -r -d com.apple.quarantine /Applications/启动台.app
```

此指令只會移除隔離標記，**不會驗證簽章或完成 Apple 公證**。若要檢查應用程式的簽章完整性，可另外執行 `codesign --verify --deep --strict /Applications/启动台.app`；臨時簽署不代表 Apple 開發者身分認證。

預設全域快速鍵為 **Control–Option–L**，可在設定中更改。搜尋欄旁的齒輪可開啟設定；其中「重新掃描應用程式」會清空目前載入的應用程式列表，並重新讀取應用程式目錄。也可按 **Command–R** 重新掃描。

設定中的「選單列圖示」可以即時顯示或隱藏啟動台圖示，選擇會儲存在應用程式資料中。隱藏後仍可透過 Dock 或全域快速鍵開啟啟動台，再重新顯示圖示。

設定中的「語言」預設跟隨 macOS 偏好語言；可手動選擇简体中文、繁體中文或 English，切換後介面立即更新並記住選擇。網格中的第三方應用程式名稱仍依 macOS／Finder 語言顯示，使用者自訂名稱也會保留。

### 透明毛玻璃主題

在設定中選擇 **淺色**，啟動台將使用透明背景及系統毛玻璃呈現桌布；選擇 **跟隨系統** 時，系統處於淺色外觀也會使用此效果。設定視窗仍保持白色底色，資料夾內容保留獨立面板。應用程式名稱使用文字陰影，提高在桌布上的可讀性。

毛玻璃由 AppKit 的 [fullScreenUI 材質](https://developer.apple.com/documentation/appkit/nsvisualeffectview/material-swift.enum/fullscreenui)與 [behindWindow 混合模式](https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/behindwindow)繪製，顯示的是視窗下方的內容：若下方有其他應用程式視窗，也會透出這些視窗。macOS 開啟「減少透明度」時，系統可能使用實色取代毛玻璃。新版透明效果尚未在 ToDesk 遠端工作階段中實測。

### 拖曳與手勢翻頁

按住滑鼠左鍵，在空白處左右拖曳即可翻頁；向左拖曳前往下一頁，向右拖曳回到上一頁。在圖示上快速橫向拖曳也可翻頁；若要排序，請按住圖示約 0.35 秒再拖曳，或直接縱向拖曳圖示。每次拖曳只切換一頁，放開後不會誤開啟應用程式或關閉啟動台。單擊空白處仍會關閉啟動台；資料夾內也支援翻頁。

滑鼠指標位於應用程式網格上時，可使用觸控式軌跡板三指橫向滑動。程式處理三指觸控事件及 AppKit 原生 swipe 事件。macOS 系統手勢可能優先接收三指操作；若三指滑動切換了桌面，請在「系統設定 > 觸控式軌跡板」的手勢選項中調整衝突項目。手勢事件的處理方式請參閱 [Apple 觸控式軌跡板事件文件](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html)。

佈局、資料夾、隱藏狀態、應用程式別名及偏好設定儲存於：

```text
~/Library/Application Support/ClassicLaunchpad/Data.store
```

更新應用程式時不需要刪除此檔案。若要重設所有個人設定，請先結束啟動台，再備份或移走此檔案。

## 完整解除安裝

僅在 Finder 中將 `启动台.app` 移到垃圾桶，不會自動刪除 `~/Library/Application Support/ClassicLaunchpad` 中的使用者資料。這是 macOS 對一般應用程式的解除安裝方式；升級時暫時移走舊版，也能保留現有佈局。

若要一併刪除設定，請先開啟已安裝的啟動台，點按搜尋欄旁的齒輪，在設定底部選擇 **「完整解除安裝啟動台…」** 並確認。應用程式會移除登入項目，將自身移到垃圾桶，再刪除應用程式資料、偏好設定、快取及視窗狀態。

若舊版應用程式已從「應用程式」移走，可按兩下掛載新版 DMG（或解壓縮備用 ZIP），再按兩下其中的 **`清理旧版残留.command`**，依提示確認清理。此工具只會刪除啟動台自己的使用者資料；若「系統設定 > 一般 > 登入項目」仍顯示舊項目，請在系統設定中移除。重新安裝或升級時，直接取代應用程式即可，不需要執行清理工具。

## 實作說明

應用程式掃描以 `/Applications` 為主，並包含系統「實用工具」目錄。應用程式套件的本地化名稱優先於套件內的英文名稱；使用者設定的別名具有最高優先順序。Dock 啟動台資料庫為可選的唯讀補充來源，資料庫不存在或結構不相容時會略過。程式不會修改系統檔案。

原始碼位於 `Sources/`，應用程式的 `Info.plist`、本地化資源及原始 PNG 圖示位於 `Resources/`。建置腳本會由 PNG 產生應用程式套件的 `.icns`；圖示包含清晰的大尺寸影像，讓 Finder 依需要縮放至列表尺寸。主程式包含語言、圖示排序及分頁相關的命令列自我測試，可使用 `dist/启动台.app/Contents/MacOS/ClassicLaunchpad --self-test-language`、`--self-test-indicator`、`--self-test-scroll` 和 `--self-test-gestures` 執行。
