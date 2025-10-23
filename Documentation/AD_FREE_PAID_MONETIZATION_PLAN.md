# 免费含广告版 + 付费去广告版实施计划

本文档为 BloodPressureCam 在保持现有功能的基础上，引入免费广告版与付费无广告版的分发方案，涵盖产品、法律、技术、测试与发布流程。当前仅为计划，尚未修改代码。

## 1. 产品与商业策略
- **目标**：通过免费版吸引全球用户，广告实现基础收入；付费版提供无广告体验并可追加增值功能。
- **定价**：
  - 免费版：`BloodPressureCam`（保留现有 Bundle ID，可含广告）。
  - 付费版：`BloodPressureCam Pro`（新建 Bundle ID，建议一次性购买价格，如 USD 4.99，可各市场调价）。
- **功能差异**：
  - 免费版：展示 Banner/Interstitial/Reward 广告（按 UX 选择），功能保持原有。
  - 付费版：完全去广告，可考虑增加云备份、历史趋势导出等增值功能（后续迭代）。
- **指标**：设定日活 DAU、广告填充率、ARPU、付费转化率等关键指标。

## 2. 广告与隐私合规
1. **选择广告网络**：评估 Google AdMob、AppLovin、Meta Audience Network 等。考虑：健康类内容政策、全球填充率、GDPR/CCPA 支持。
2. **注册账号**：创建广告网络账户，完成付款信息、税务资料。
3. **隐私政策更新**：增加广告 SDK 数据使用说明、追踪信息、用户选择退出渠道。
4. **App Tracking Transparency (ATT)**：规划授权弹窗文案，明确广告用途；若使用 Google UMP 等 SDK，集成同意收集逻辑。
5. **儿童/医疗合规**：确认不针对 13 岁以下，广告内容符合健康应用规定；若涉及医疗器械声明，避免误导广告。
6. **数据收集申报**：更新 App Store Connect 的“App Privacy”条目，标注广告追踪相关数据。

## 3. 技术实现规划
1. **代码结构**：
   - 保持单一代码仓库，创建两个 Xcode Target：`BloodPressureCam-Free` 与 `BloodPressureCam-Pro`。
   - 使用 Build Configurations 或编译宏（如 `FREE_EDITION`）区分广告逻辑。
2. **广告 SDK 集成**：
   - 通过 Swift Package Manager 或 CocoaPods 引入（例如 Google-Mobile-Ads-SDK）。
   - 在免费目标中链接库；付费目标排除。
3. **广告位设计**：
   - Banner：血压结果页底部（确保留白、避免遮挡关键信息）。
   - Interstitial：适度使用，如完成测量后；设置频率控制与冷却时间。
   - Reward（可选）：换取额外历史记录、导出功能等。
   - 记录广告显示规则（例如每次测量最多 1 次插屏，Banner 不影响测量流程）。
4. **配置管理**：
   - Info.plist：为免费版添加 `GADApplicationIdentifier`、ATT 说明等。付费版保持精简。
   - 资源差异：应用名称、图标（可加上 “Pro” 标识）。
5. **Feature Flag**：
   - 创建 `AdServiceProtocol` 抽象；免费版提供真实实现，付费版返回 `nil`。
   - 便于未来引入 IAP 去广告（单一应用方案时可复用）。
6. **分析埋点**：
   - 集成广告展示/点击事件，配合 Firebase Analytics 等统计用户行为。
7. **自动化构建**：
   - 更新 `project.yml`/Xcodeproj，配置两目标的签名证书与 Provisioning Profile。
   - Fastlane（如使用）需增加两个 lanes：`free_release`、`pro_release`。

## 4. 法务与财务准备
1. **App Store Connect**：
   - 新建付费应用记录（Bundle ID `com.company.BloodPressureCamPro`）。
   - 免费版保持原记录，元数据新增广告说明。
2. **合约与税务**：
   - 确认广告收入相关税务（AdMob vs Apple）与 Apple 付费 App 销售税务。
   - 更新开发者协议，确保两个版本均覆盖在 Apple Developer Program 下。
3. **支持条款**：
   - 用户协议中区分免费/付费权益，广告条款。

## 5. 设计与本地化
1. **UI 调整**：为 Banner 预留安全区域，设计 Pro 版图标、App Store 截图。
2. **App Store 文案**：
   - 两套元数据（免费/付费），强调差异化卖点。
   - 本地化广告说明与付费优势。
3. **应用内提示**：在免费版添加升级 Pro 的提示（尊重 App Store 指南 3.1.1，避免外链引导外部购买）。

## 6. QA 与测试计划
1. **功能测试**：验证广告加载、频控、网络异常处理、无广告版本体验。
2. **隐私测试**：ATT 授权、GDPR 同意流程、撤回同意流程。
3. **性能测试**：确保广告 SDK 不影响相机功能与测量性能。
4. **Beta 测试**：
   - 免费版和 Pro 版分别使用 TestFlight，邀请不同群组测试。
5. **崩溃监控**：集成 Crashlytics 或 Xcode Organizer 崩溃日志。

## 7. 发布与运营
1. **版本控制**：同步维护两个 target 的版本号；可共享核心代码，使用 Git 分支管理改动。
2. **提交审核**：
   - 免费版需在提交说明中解释广告位置、类型。
   - Pro 版强调无广告体验。
3. **上线策略**：
   - 先小范围地区上线免费版广告功能，监控反馈，再全球推广。
   - 同步上线 Pro 版或稍后推出，配合营销活动。
4. **广告优化**：上线后监控 eCPM、填充率、用户留存，必要时调整广告类型或频率。
5. **用户支持**：准备 FAQ，解释广告出现原因以及如何升级 Pro。

## 8. 后续路线
- 评估是否在免费版内提供 “去广告内购” 作为额外选项（需遵守 App Store 支付政策）。
- 根据数据决定是否引入订阅模型（例如高级功能 + 去广告）。
- 定期复审隐私与法规响应（GDPR/CCPA/ATT 更新）。

该计划完成后，可按章节分配给相应团队成员执行；待确认后再进行代码层面的具体实现。
