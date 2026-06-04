# 📱 Gentle Night · iOS（原生 SwiftUI 版）

把网页版用 **SwiftUI 原生重写**的源码。功能与网页版一致：双主题、每日记录、罐子珠子（柔雾配色 + 物理堆叠 + 很好档星芒）、数据驱动评语、中英文小语、落入罐子动效 + 柔和音效、本地 `UserDefaults` 存储。

> 要求：Xcode 15+，部署目标 **iOS 16.0 及以上**。

## 如何加进你的 Xcode 项目

1. 你已在 Xcode 新建项目 `gentle_night`（Interface: SwiftUI，Storage: None，Testing: None）。
2. 把本文件夹 `GentleNight/` 里的这些 `.swift` 文件，全部拖进 Xcode 左侧项目导航器：
   - `Model.swift` · `Palette.swift` · `Quotes.swift` · `Components.swift`
   - `Sound.swift` · `JarView.swift` · `TonightView.swift` · `TrendsView.swift`
   - `ContentView.swift` · `gentle_nightApp.swift`
   - 拖入时勾选 **Copy items if needed**，Target 勾上 **gentle_night**。
3. 项目里**原本就有** `gentle_nightApp.swift` 和 `ContentView.swift`：
   - 用我提供的同名文件**覆盖内容**（直接打开原文件，把我的内容整段粘贴进去），
   - 或先删掉原来的两个，再加入我的——⚠️ 注意整个项目只能有**一个 `@main`**。
4. `⌘R` 运行（模拟器或真机）。首次真机运行需在手机「设置 → 通用 → VPN与设备管理」信任你的开发者证书。

## 文件结构

| 文件 | 作用 |
|---|---|
| `Model.swift` | Metric / Entry / Store(UserDefaults 存储) / 评语逻辑 |
| `Palette.swift` | 珠子柔雾色阶(分数→颜色) + 主题自适应配色 |
| `Quotes.swift` | 50+50 组中英文小语 |
| `Components.swift` | 月牙、珠子、星芒闪烁、物理堆叠算法、评分球 |
| `Sound.swift` | 合成的柔和音效（落珠/盖盖/收尾铃音） |
| `JarView.swift` | 玻璃罐 + 珠子排布 |
| `TonightView.swift` | 记录页 + 「晚安」落入罐子动效 |
| `TrendsView.swift` | 趋势页（时间范围 / 罐子 / 评语 / 横幅） |
| `ContentView.swift` | Tab 框架 + 右上角主题切换 |

## 说明 / 后续可精修

- 卡片大图标当前用 **SF Symbols**（sun/leaf/sparkles）。想完全复刻网页那种「萌系手绘脸」，可改成自定义 SVG/Shape，后续我可以再做。
- 主题：默认跟随系统，右上角按钮可手动切换并记住。
- 数据仅存本机 `UserDefaults`，不联网、不上传。
