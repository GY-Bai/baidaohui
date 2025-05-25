task1:你是一位 Flutter 重构助手。  
项目已接入 `forui` 组件库，但所有 `FButton` 仍错误地使用 `onPressed:`。  
**请做：**
1. 在整个 `lib/` 目录递归查找 `FButton(` 到其 `);` 之间是否出现 `onPressed:`。  
2. 将其批量替换为 `onPress:`，其余参数保持不动。  
3. 输出：  
   • 受影响文件路径 + 行号列表  
   • diff 片段（±3 行上下文）证明已替换成功。  
   • 若无匹配项请返回 “无替换”。  

task2:背景：项目页面仍大量使用 Material `Scaffold / AppBar`。forui 要求使用  
`FScaffold(child: …, header: FHeader(...), footer: …)` :contentReference[oaicite:2]{index=2}。  
**请做：**
1. 依次处理 `lib/pages/*.dart` 内的 `Scaffold`：  
   • 替换为 `FScaffold`；  
   • `appBar:` 内部移到 `header:`，用 `FHeader(title: const Text('...'))`；  
   • `body:` 改为 `child:`；  
   • 如有 `bottomNavigationBar:` 移到 `footer:` 并改 `FBottomNavigationBar`。  
2. 保留原业务逻辑与状态管理。  
3. 提交每个页面的完整新代码。  

task3:目标：把所有 Material `ElevatedButton / TextButton / OutlinedButton / TextField / Switch / Checkbox / Slider / AlertDialog / SnackBar`  
替换成 forui 对应组件：

| Material | forui | 备注 |
|----------|-------|------|
| Scaffold | FScaffold |
| AppBar | FHeader |
| Elevated/Text/OutlinedButton | FButton (style 选 primary / secondary / outline) |
| TextField | FTextField (若需验证可继续用 Form) |
| Switch | FSwitch |
| Checkbox | FCheckbox |
| Slider | FSlider |
| AlertDialog | FDialog |
| SnackBar | FAlert 或 FDialog+FProgress |

请分步骤执行：  
1. 先在 `lib/widgets/` 目录完成替换，确保封装组件已迁移；  
2. 再在 `lib/pages/` 里调用新的封装；  
3. 给出至少一处前后对比 diff 示例。  

task4:1. 在 `main.dart` 根组件 `MaterialApp` 外包一层：
   FTheme(
     data: FThemes.zinc.light, // 先用默认主题
     child: MaterialApp(...)
   )
2. 移除任何自定义颜色的 `AppBar(backgroundColor: ...)`，改为在 `FThemeData` 或单独的 `header.style` 里配置。  
3. 确保所有页面能通过 `context.theme` 调主题色 & typography。  
4. 提交修改后的 `main.dart` 完整代码。  

task5:1. 跑 `flutter analyze`，收集 “unused_import” 与 “parameter XXXX isn't defined for FScaffold/FButton” 报错。  
2. 对每个文件：  
   • 若仅剩 forui 组件，则删 `package:flutter/material.dart`；  
   • 如仍用到 `Icons / Navigator / ThemeData` 等，可保留。  
3. 输出清单：文件路径 + 删除的 import 行（diff 格式）。  

task6:1. 重新执行 `flutter pub get && flutter analyze` —— 预期 0 个错误，只剩 info / warning。  
2. 执行现有测试 `flutter test`，或若无测试请临时生成一个 smoky test：  
   testWidgets('App builds', (tester) => tester.pumpWidget(const Application()));  
3. 输出控制台结果截图或纯文本日志，证明无编译错误。  

task7:请列一个 QA 自测点表（至少 10 项）：  
• UI（Header、Footer、按钮样式）  
• 功能（登录流程、表单提交、图片上传、路由跳转）  
• 响应式（手机 / 平板 / 桌面宽度）  
• 深色模式（若主题已支持）  
• 可访问性（语义标签、键盘导航）  
格式：Markdown 表格，列 “模块 / 测试步骤 / 预期结果 / 实际结果(填 ✓/✗)”。
