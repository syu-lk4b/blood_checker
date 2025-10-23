# 真机测试指南

本文档介绍如何将 BloodPressureCam 安装到真实 iPhone 设备上进行调试与功能验证。

## 1. 环境要求
- macOS 13 及以上，已安装 Xcode 15 与 Command Line Tools。
- 一台运行 iOS 15 或更高版本的 iPhone，配备数据线（或使用同一 Wi-Fi 网络做无线调试）。
- 可用的 Apple ID：
  - 个人开发者可以使用免费 Apple ID 进行签名（需每 7 天重新部署）。
  - 若有 Apple Developer Program 付费账号，可生成长期证书与配置文件。
- 已在项目目录执行过 `xcodegen generate`，确保存在 `BloodPressureCam.xcodeproj`。

## 2. 连接与信任设备
1. 使用数据线连接 iPhone 与 Mac，若弹出 “是否信任此电脑” 在手机上点击“信任”并输入锁屏密码。
2. Mac 上打开 Finder，左侧设备列表中选中 iPhone，勾选 “显示此 iPhone 时自动信任”。
3. 若计划无线调试，在 Finder 中勾选 “在 Wi-Fi 上显示此 iPhone”。

## 3. 打开工程与配置签名
1. 在终端进入项目根目录：
   ```bash
   cd /Users/syu/Desktop/AI_example/blood_check/BloodPressureCam
   open BloodPressureCam.xcodeproj
   ```
2. 在 Xcode 左上角选择 `BloodPressureCam` 目标。
3. 选择实际设备：点击运行按钮旁的设备下拉，选中已连接的 iPhone。
4. 进入 `TARGETS > BloodPressureCam > Signing & Capabilities`：
   - 勾选 `Automatically manage signing`。
   - 在 `Team` 中选择自己的 Apple ID 所属团队。
   - 将 `Bundle Identifier` 修改为唯一值（例如 `com.yourname.BloodPressureCam`），避免与已存在的 App 冲突。

## 4. 启用 Developer Mode（iOS 16+）
1. 首次在 Xcode 部署到真机时，系统会提示“需要开启开发者模式”。
2. 在 iPhone 上前往 `设置 > 隐私与安全性 > 开发者模式`，打开开关。
3. 根据提示重启设备，重启后在弹窗中点击“打开”。

## 5. 设备在 Xcode 中的状态
1. Xcode 菜单选择 `Window > Devices and Simulators`。
2. 在 `Devices` 页签中确认设备状态为 `Paired`，且主界面顶部设备下拉不再显示感叹号。
3. 若显示 `Pair` 按钮或证书问题，点击旁边的感叹号修复，或在设备上再次点击“信任此开发者”。

## 6. 构建并安装应用
1. 保持目标设备连接，按 `⌘R` 或点击运行按钮。
2. 首次安装会触发代码签名和安装流程，Xcode 底部状态提示 `Running BloodPressureCam on <Device Name>`。
3. 如在设备上弹出 “信任开发者” 提示：
   - 前往 `设置 > 通用 > VPN 与设备管理`。
   - 选择对应的开发者证书，点击“信任”。
   - 再次在 Xcode 中点击运行完成安装。
4. 成功后 App 会自动启动至首页。

## 7. 功能验证建议
- **相机权限**：启动时允许相机访问，测试拍照流程与生成报告的流程。
- **相册访问**：在添加照片时授权访问，验证从相册选择图片的体验。
- **本地数据存储**：新增、编辑与删除测量记录，确认在重新打开 App 后数据仍存在。
- **报告导出**：执行“导出报告”，确保生成的 PDF 可以通过分享面板发送至 Files / AirDrop。
- **性能与体验**：观察在实机拍照、滚动图表等场景下的流畅度。

## 8. 常见问题排查
- **`Signing certificate is invalid`**：在 `Xcode > Settings > Accounts` 重新登录 Apple ID，并在 `Manage Certificates…` 中创建或刷新 `iOS Development` 证书。
- **`A valid provisioning profile for this executable was not found`**：回到 `Signing & Capabilities` 页面确保勾选自动签名，等待 Xcode 生成并同步配置文件。
- **设备下拉显示锁图标**：说明未在手机上信任开发者，按照第 6 节步骤信任证书后重新运行。
- **构建成功但 App 未安装**：检查 iPhone 存储空间是否充足，或在 `Settings > General > Transfer or Reset iPhone` 中重启设备后重试。
- **相机黑屏或崩溃**：确认真机已授予权限，可在 `设置 > 隐私 > 相机` 中清除并重新授权。

## 9. 保持证书与设备列表
- 免费账号每 7 天需要重新 `Run` 一次应用；如超过期限 App 会自动失效，需要重新安装。
- 在 Xcode 的 `Devices and Simulators` 窗口可右键设备名称导出日志，便于定位崩溃。
- 建议定期在 `Window > Organizer > Archives` 中归档正式包，便于后续提交 TestFlight 或 App Store。

完成以上步骤后，即可在真实设备上验证 BloodPressureCam 的核心功能。祝调试顺利！
