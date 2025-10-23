# 技术架构与设计说明

## 架构概览
- **UI 层**：采用 SwiftUI，`TabView` 管理五个功能子模块。复杂视图拆成独立组件，减少状态耦合。
- **数据模型**：`BloodPressureReading` 使用 `Codable` 序列化，定义 `Feeling`、`MeasurementPosture` 等枚举用于展示文案。
- **持久化**：`MeasurementStore` 通过 JSON 文件存储，结合 `PhotoStorage` 保存 JPEG 照片。数据更新统一走 `DispatchQueue` 保证线程安全。
- **服务层**：
  - `PhotoStorage` 负责管理图片文件生命周期。
  - `ReportGenerator` 使用 `ImageRenderer` + `PDFKit` 将 SwiftUI 视图导出为 PDF。
- **统计分析**：`ReportMetrics` 用于计算平均值、极值与趋势文本。`DateRangeOption` 提供常用时间窗口。

## 关键设计考量
1. **离线优先**：所有数据均存储在本地，便于在手机中随时查看。
2. **渐进式智能录入**：当前版本仍需手动校准；将来可在 `CaptureEntryView` 中接入 OCR 推断数值。
3. **可测试性**：`MeasurementStore` 支持自定义 `baseURL`，便于在测试中注入临时目录。
4. **导出能力**：报告视图与界面大体一致，用户无需额外设计即可分享给医生。
5. **国际化准备**：界面文案集中在 SwiftUI 视图，可进一步抽取为 `Localizable.strings`。

## 扩展建议
- 集成 HealthKit 同步血压数据
- 使用 Core Data 或 CloudKit 提供多设备同步
- 接入通知框架，根据 `reminderHour/Minute` 安排本地提醒
- 引入 OCR（VisionKit / Core ML）自动识别血压计读数
- 提供数据导入导出（CSV）
