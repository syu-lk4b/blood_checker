# 广告平台选择与个人操作指南

本文档梳理适用于 BloodPressureCam 免费版的主要移动广告平台、各平台在 Apple 审核下的注意事项，以及作为个人开发者或小团队需要完成的注册与合规操作。同时列出不建议使用或可能被 Apple 拒绝的广告来源。

## 1. Apple 审核允许的主流广告平台
下述平台均被广泛用于 iOS 应用，并且共有明确的隐私与合规文档。最终能否通过审核取决于实现方式及应用内容，需确保遵守 App Store Review Guidelines（尤其是 1.4 健康、2.3.12 广告、5.1 隐私）。

### 1.1 Google AdMob
- **适用性**：支持全球填充率，提供健康/医疗敏感分类过滤。可通过 Google Play Services for iOS（Google Mobile Ads SDK）集成。
- **Apple 注意事项**：需要在 Info.plist 填写 `GADApplicationIdentifier`，实现 ATT 请求；不得展示违规类广告。
- **个人操作步骤**：
  1. 使用 Google 账号登陆 https://admob.google.com。
  2. 验证个人身份（手机号、国家/地区）。
  3. 填写付款资料：个人银行账户、税务资料（美国税 W-8BEN）。
  4. 创建应用条目（选择 iOS），获取 App ID 和广告单元 ID。
  5. 配置内容过滤（Sensitive categories、Ad content rating）。
  6. 下载/导入 Google-Mobile-Ads-SDK（SPM/CocoaPods）并集成。
  7. 如投放欧盟地区，启用 Google UMP Consent SDK 处理 GDPR 同意。

### 1.2 AppLovin MAX
- **适用性**：聚合平台（Mediation），可接入多个广告源，提升收益。支持 iOS，并提供个人开发者账户。
- **Apple 注意事项**：确保不展示医疗不当广告，ATT 说明需涵盖跨应用追踪。
- **个人操作步骤**：
  1. 访问 https://www.applovin.com/ MAX 平台注册账号。
  2. 完成邮箱验证，选择 "Individual" 或 "Small Business"。
  3. 填写公司信息（可用个人名称）、税务表（W-9/W-8），绑定银行账户或 PayPal。
  4. 创建应用条目，配置广告格式（Banner/Interstitial/Rewarded）。
  5. 按需集成其他网络（AdMob、Meta 等）作为 bidding 网络，获取各自密钥。
  6. 在项目中通过 SPM/CocoaPods 引入 AppLovin SDK，设置 mediation。
  7. 配置 GDPR/CCPA 合规：AppLovin 提供隐私设置 API，需在应用内提供同意界面。

### 1.3 Unity LevelPlay（原 ironSource）
- **适用性**：聚合平台，支持多广告源、细粒度控制。适合需集中管理的团队。
- **Apple 注意事项**：注意避免被视为游戏专属广告网络，需确保广告类型适配健康类应用。
- **个人操作步骤**：
  1. 访问 https://developers.is.com/ 注册账号，选择独立开发者。
  2. 完成邮箱验证，填写个人或公司资料。
  3. 提交税务和付款信息（银行/PayPal）。
  4. 在平台创建 iOS 应用，启用所需广告格式。
  5. 获取 App Key，集成 ironSource/LevelPlay SDK。
  6. 如接入其他网络，需在各网络创建账号并在 LevelPlay 中配置密钥。
  7. 实现隐私合规：使用他们的 GDPR API，确保 ATT 提示。

### 1.4 Meta Audience Network
- **适用性**：以 Facebook/Instagram 生态为主的广告平台，擅长精准投放。适合需高 eCPM 的地区。
- **Apple 注意事项**：Meta SDK 收集数据，务必在 ATT 中说明；需遵守 Meta 健康类内容政策。
- **个人操作步骤**：
  1. 需要 Facebook 开发者账号（https://developers.facebook.com/）。
  2. 在 Business Manager 中创建应用，启用 Audience Network。
  3. 完成业务验证（可能需要上传身份证明、地址证明）。
  4. 填写税务信息与付款设置。
  5. 创建 Placement ID 并集成 Meta Audience Network SDK。
  6. 在应用中实现用户追踪同意流程，处理 GDPR/CCPA 请求。

### 1.5 Apple Search Ads 内嵌广告（限制）
- Apple 自带的广告服务主要用于 App Store 推广，不适合应用内广告；此处仅列出说明不适用。

## 2. Apple 可能拒绝或不建议使用的广告平台
- **未经过审查的本地广告 SDK**：如果来源不明、缺乏隐私政策或涉及动态脚本下载，易触犯 Guideline 2.5.2（包含隐藏功能）或 5.1（隐私）。
- **含成人、博彩、加密货币高风险广告平台**：健康应用展示敏感内容可能直接被拒。
- **带有激进弹窗/锁屏广告 SDK**：违反用户体验条款（Guideline 2.5.6）。
- **使用 WebView 注入第三方广告脚本**：Apple 对未声明的追踪/代码下载非常严格，可能造成拒审。
- **越狱或企业证书专用广告源**：这类渠道通常不被允许进入 App Store。

## 3. 通用个人开发者操作清单
1. 确认 Apple Developer Program 账号有效，Bundle ID 使用公司或个人名义。
2. 为每个平台准备：
   - 个人身份证明（护照/驾照）。
   - 银行账户信息（SWIFT/IBAN）或 PayPal。
   - 税务信息（美国市场常见：W-8BEN for individuals）。
   - 联系邮箱、电话。
3. 阅读并保存各广告网络的服务条款、隐私政策，确保内容可引用。
4. 为 GDPR/CCPA 准备：
   - 隐私政策网页可随时更新。
   - 应用内提供“同意/拒绝广告追踪”入口。
5. 在 App Store Connect 更新“App Privacy”，列出各 SDK 收集的数据类型，并回答 Tracking 问卷。
6. 在 Xcode 项目中预留广告开关（编译宏/配置），便于审核时切换。

## 4. 选择建议
- 若希望快速上线、全球覆盖：**AdMob** 作为起点，结合 **AppLovin MAX** 做聚合。
- 若预算有限、仅自己维护：优先选择单一网络（AdMob）并关注合规。
- 若要优化收益：使用聚合（AppLovin MAX/LevelPlay）整合多个网络，同时保持隐私合规。

使用上述平台时，务必在 TestFlight 阶段实际加载广告，确保不会因网络或配置问题在审核期间无法展示或展示违规内容。
