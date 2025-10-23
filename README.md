# BloodPressureCam

BloodPressureCam 是一个 SwiftUI iOS 应用示例，支持通过相机拍照记录家庭血压仪读数、手动校准与补充信息、生成统计与报告，并在本地持久化存储数据与照片。项目依据提供的界面截图重新设计，并附有完整文档、测试、安装与使用说明。

> **最低系统需求**：Xcode 15、iOS 16（使用 SwiftUI `Charts` 与 `ImageRenderer`）

## 功能概览
- 相机拍照并保存血压计屏幕（含权限引导）
- 手动录入或校准血压、高压/低压/心率、体感、姿势、体重等信息
- 列表浏览、详情查看与编辑、照片回看
- 统计页展示近期趋势折线图及关键指标
- 报告页生成图文报告，支持导出 PDF 并通过系统分享
- 设置页提供高压高亮、测量提醒等基础偏好设置

## 目录结构
```
BloodPressureCam/
├─ project.yml                 # XcodeGen 项目描述
├─ README.md                   # 顶层总览
├─ Sources/                    # SwiftUI 应用源码
│  ├─ BloodPressureCamApp.swift
│  ├─ Info.plist
│  ├─ Models/
│  ├─ Services/
│  ├─ Utilities/
│  ├─ Views/
│  └─ Resources/
├─ Tests/                      # XCTest 用例
└─ Documentation/              # 安装、使用、测试文档
```

详细文档请参见 `Documentation/` 目录。
