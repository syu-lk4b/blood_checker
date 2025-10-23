# 测试说明

## 自动化测试
项目提供最小化的 XCTest 覆盖 `MeasurementStore` 的持久化能力，包括：
- 新增记录后能写入持久化文件
- 初始化时能读取已有 JSON 数据

### 运行步骤
1. 确保已使用 `xcodegen generate` 生成 `.xcodeproj`。
2. 在 Xcode 选择 `BloodPressureCam` 方案下的 `BloodPressureCamTests` 目标。
3. 通过快捷键 ⌘U 或者菜单 `Product → Test` 执行测试。

命令行运行示例：
```bash
xcodebuild \
  -scheme BloodPressureCam \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

## 手动验证建议
为确保相机、图表和 PDF 导出在真实环境中的体验，建议手动执行以下验证：
1. **权限流**：首次启动时授予/拒绝相机权限，确认提示正确。
2. **拍照流程**：拍摄血压计屏幕，进入手动录入页确认照片展示。
3. **编辑/删除**：编辑已有记录并检查数据、照片是否更新；删除后确认列表与文件中均被移除。
4. **报告导出**：生成 PDF 并使用“存储到文件”“邮件分享”等渠道测试可用性。
5. **国际化**：切换系统为中文与英文，确认主要文案显示合理（当前默认中文，可在 `Localizable` 中扩展多语言）。
