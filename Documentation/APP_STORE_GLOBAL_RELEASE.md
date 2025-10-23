# 全球 App Store 上架准备步骤

以下步骤以 BloodPressureCam 为例，涵盖将 iOS 应用发布到全球 Apple App Store 前需要完成的准备工作。可根据团队职责拆分，但建议按顺序执行。

## 1. 注册与法律准备
1. **Apple Developer Program**：确保使用公司或个人 Apple ID 加入 Apple Developer Program（https://developer.apple.com/programs/），完成年费支付。
2. **公司与品牌审查**：准备营业执照/纳税证明、应用商标、版权授权，确保拥有足够权利在所有目标市场发布。
3. **合规评估**：审阅 App Store Review Guidelines，重点关注 1.4 健康与医疗、5.1 隐私、5.2 法律条款。确认应用不涉及需要当地医疗器械认证的功能，或准备相关资质。

## 2. 应用合规与隐私
1. **隐私政策**：撰写隐私政策，托管在官网。必须涵盖数据采集、存储、共享、联系方法。
2. **App Privacy Details**：列出应用收集的所有数据类型（健康、通讯录、位置信息等），标注用途、是否关联用户、是否用于追踪。
3. **App Tracking Transparency (ATT)**：如需追踪，集成 ATT 授权流程并说明用途。否则确认不使用第三方追踪。
4. **加密与出口合规**：若使用非标准加密或传输健康数据，准备回答 Export Compliance 问卷。

## 3. 本地化策略
1. **目标市场清单**：列出要覆盖的国家/地区，识别语言、货币、假日、文化差异。
2. **文本与 UI 多语言**：准备本地化字符串文件（.strings）、约束适配、RTL 支持（阿拉伯语、希伯来语）。
3. **应用内内容审查**：确保单位、血压参考范围符合不同地区的医学标准或提供说明。
4. **法律声明**：在每种语言中提供责任声明，明确应用仅供健康参考，非医疗诊断。

## 4. 资产与素材准备
1. **App 图标**：确保 AppIcon 已包含 iPhone/iPad/Marketing 所需尺寸（已完成）。
2. **启动屏幕与品牌**：准备 Launch Screen storyboard，保证在所有语言下无文字（或已本地化）。
3. **App Store 截图**：每个目标语言/设备尺寸（5.5"、6.5"、iPad、iPad Pro等）准备截屏，包含本地化文案。
4. **宣传视频（可选）**：如需 App Preview，按要求录制并本地化字幕。
5. **描述与关键字**：撰写多语言版本的应用名称、Subtitle、Description、Keywords、Promotional Text。

## 5. 财务与联系信息
1. **银行账户**：在 App Store Connect 中填写收款账号（地区、SWIFT、IBAN）。
2. **税务文件**：完成美国 W-8/W-9、以及各目标市场可能需要的税务表。
3. **支持联系方式**：提供电子邮件、网站支持页面、电话（如适用）。
4. **营销 URL**：准备应用官网或落地页链接。

## 6. 技术准备
1. **Bundle Identifier**：在 Apple Developer Center 创建唯一 Bundle ID 与 App ID，并配置所需能力（摄像头、HealthKit 等）。
2. **Provisioning Profiles & Certificates**：创建分发证书（App Store）和相应预配文件，更新到 Xcode。
3. **版本号策略**：确认 CFBundleShortVersionString / Build 号递增策略。
4. **最低系统版本**：设置部署目标，并验证所有设备上的兼容性。
5. **HealthKit 与权限**：如使用 HealthKit，提供使用说明字符串（NSHealthShareUsageDescription 等）。
6. **自动化测试**：运行单元/UI 测试，生成测试报告。准备 LQA（语言质量测试）记录。

## 7. TestFlight 与 QA
1. **上传构建**：使用 Xcode Organizer 或 `xcodebuild -exportArchive` 将 .ipa 上传至 App Store Connect。
2. **Internal Testing**：邀请团队成员进行内部测试，填写测试备注。
3. **External TestFlight**：如需外部测试，提交 Beta App Review，收集反馈并修复问题。
4. **回归测试**：确认所有修复已回归测试通过。

## 8. App Store Connect 配置
1. **创建 App 记录**：填写名称、副标题、主要类目/次要类目、Bundle ID、SKU。
2. **定价与上架计划**：选择销售地域（可勾选“Select All Countries or Regions”），设置价格层级和发售日期（手动/自动）。
3. **App 信息**：输入隐私政策 URL、营销 URL、支持 URL、联系方式。
4. **App 隐私详情**：按照准备的隐私矩阵填写数据收集情况。
5. **附加问卷**：完成内容权重、加密、出口、广告标识符、Age Rating 问题。
6. **本地化元数据**：为每种语言填写名称、描述、关键字、截图，确保与应用内容一致。
7. **In-App Purchases（如有）**：先在 App Store Connect 创建并审核，确保元数据完整。

## 9. 提交审核
1. **最终检查**：确认最新构建选择为“准备提交”，元数据无缺。
2. **附加资料**：如应用需要医疗法规说明，上传证明文件。
3. **提交审核**：点击“Submit for Review”，跟进可能的审核问答（App Review Notes 中说明特殊功能或演示账号）。
4. **审核反馈**：若被拒，查看 App Review Notes，修复后重新提交。

## 10. 发布与后续
1. **上线计划**：选择手动发布或自动发布。若为全球同步上线，考虑时区差异。
2. **公告与营销**：准备新闻稿、社交媒体、邮件营销、应用内更新提示。
3. **监控指标**：上线后监控 App Analytics、Sales and Trends、崩溃日志、用户反馈。
4. **持续更新**：制定迭代计划，跟踪各市场法规变化（如欧盟 GDPR、加州 CCPA 等）。
5. **本地客服**：确保支持渠道能处理不同语言和时区的用户请求。

## 11. 记录与模板
- 建议在团队文档中维护“版本发布清单”，记录每次提交的构建号、变更、审核结果。
- 为多语言内容建立翻译记忆库，便于后续更新。
- 定期复审隐私政策、用户协议，保持最新。

完成以上步骤后，BloodPressureCam 就具备在全球 Apple App Store 上架的基本条件。根据各市场法律法规，还需额外关注当地医疗、数据保护要求。
