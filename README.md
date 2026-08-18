# SwipeClean

SwipeClean 是一个使用 SwiftUI 与 PhotoKit 构建的本地照片清理工具，交互参考 SwipePo，但不复制其品牌或素材。

## 已实现

- 照片图库完整/受限授权
- 随机、最近、截图、视频、相似连拍、往年今日六种入口
- 左滑或上滑加入待删除；右滑保留；下滑收藏
- 操作撤销和本地进度保存
- 删除前网格复核，可逐项移出删除队列
- 调用 PhotoKit 执行系统级删除并显示 iOS 二次确认
- iCloud 照片按需下载缩略图；全部处理均在设备本地完成

相似照片 MVP 使用“拍摄时间相差不超过 8 秒且尺寸相同”进行分组。这种方法速度快且不会上传照片。后续可使用 Vision Feature Print 增加视觉相似度比较。

## 运行

1. 在 macOS 14 或更新系统安装 Xcode 16。
2. 打开 `SwipeClean.xcodeproj`。
3. 选择 SwipeClean Target → Signing & Capabilities，选择你的 Apple Developer Team。
4. 将 Bundle Identifier 从 `com.example.SwipeClean` 改成自己的唯一标识。
5. 连接 iPhone 或选择模拟器，然后运行。

照片清理必须优先在真机测试。模拟器可以通过系统“照片”App导入测试图片。

## GitHub 云构建

仓库包含 `.github/workflows/ios-build.yml`。推送到 `main` 或手动运行工作流后，会使用 GitHub 的 macOS Runner：

1. 验证 Xcode 工程结构；
2. 编译 iOS Simulator Debug 版本；
3. 上传 `SwipeClean-Simulator.app.zip` 和构建日志。

模拟器包用于验证编译和大部分界面流程，不能安装到普通 iPhone。生成真机 IPA 需要 Apple Developer Team、发布证书和描述文件，建议后续通过 GitHub Environments 与加密 Secrets 配置。

## 上架前必须补充

- 1024×1024 App 图标及完整 AppIcon 资源
- 隐私政策、支持页面和 App Store 隐私声明
- 单元/UI 测试与大图库性能测试
- 本地化文案
- 若加入压缩：必须先验证新文件完整写入，再请求删除原件
