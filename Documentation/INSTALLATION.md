# 安装部署指南

本指南介绍如何在本地构建并运行 BloodPressureCam。

## 预备条件
- macOS 13 及以上
- Xcode 15（含 Command Line Tools）
- CocoaPods 无需安装；项目使用 Swift Package。
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（用于从 `project.yml` 生成 `.xcodeproj`）

### 安装 XcodeGen
```bash
brew install xcodegen
```

## 获取源码
将仓库目录拷贝或克隆到本地，例如：
```bash
cd ~/Workspace
cp -R /Users/syu/Desktop/AI_example/blood_check/BloodPressureCam ./BloodPressureCam
cd BloodPressureCam
```

## 生成 Xcode 工程
```bash
xcodegen generate
```
运行后将得到 `BloodPressureCam.xcodeproj`。

## 打开项目
```bash
open BloodPressureCam.xcodeproj
```
在 Xcode 中选择 `BloodPressureCam` 目标，`Any iOS Device (arm64)` 或模拟器 (iPhone 15 等)。

## 配置运行
1. 如需真机调试，请在 “Signing & Capabilities” 中选择自己的 Team，Xcode 会自动生成 Bundle Identifier。
2. 首次运行会请求相机与照片权限，务必允许。

## 构建与启动
在 Xcode 顶部工具栏点击 “Run” (⌘R) 构建并部署到选择的设备或模拟器。
