# Repository Guidelines

## Project Goal
- 核心目标：在 iOS 侧实现类似 Android `PopScope` 的返回拦截能力。
- 现实约束：iOS 没有直接可用的“返回意图（back intent）”信号，Flutter 也无法直接获取。
- 项目策略：由插件主动“创造”并向 Flutter 暴露稳定、可控的类 back intent 信号（基于 iOS 手势与导航状态）。
- 最终效果：业务接入组件后，受影响页面在 iOS 上也能获得接近 Android `PopScope` 的可控返回体验。

## Project Structure & Module Organization
- `lib/` contains the Dart API. Key files: `popscope_ios.dart`, `popscope_ios_method_channel.dart`, `popscope_ios_platform_interface.dart`, plus `widgets/` and `utils/`.
- `ios/popscope_ios/Sources/popscope_ios/` contains the Swift plugin (`PopscopeIosPlugin.swift`) and iOS privacy file.
- `example/` is the demo app; entrypoints in `example/lib/` (e.g., `main.dart`, `main_custom.dart`, `main_popscope.dart`) with pages and widgets.
- `test/` holds package tests; `example/test` and `example/integration_test` cover the example app.
- `docs/` has experiments/notes; `build/` is generated output.

## Requirements
- Flutter >= 3.3.0, Dart >= 3.0.0, iOS >= 12.0 (see README for compatibility).

## Build, Test, and Development Commands
- `flutter pub get` — install dependencies.
- `flutter analyze` — run lint/analysis (uses `flutter_lints`).
- `flutter test` — run package tests in `test/`.
- `flutter test test/popscope_ios_method_channel_test.dart` — run a single test file.
- `cd example && flutter run` — launch the example app.
- `cd example && flutter run lib/main_custom.dart` (or `lib/main_popscope.dart`) — run alternate demo flows.

## Coding Style & Naming Conventions
- Use Dart/Flutter formatting (`dart format .`) and keep `flutter analyze` clean.
- Indentation is 2 spaces; prefer trailing commas for Flutter widget trees.
- Types use `UpperCamelCase`, members `lowerCamelCase`, and files `snake_case` (see `lib/` and `example/lib/`).

## Testing Guidelines
- Unit/widget tests use `flutter_test`; add tests for new MethodChannel behavior and widget callbacks.
- Example integration tests live in `example/integration_test`; run them from the example app as needed.
- For iOS gesture behavior changes, manually verify with the example app and consult `TESTING_CHECKLIST.md`.

## Commit & Pull Request Guidelines
- Commit messages follow `<类型>: <描述>` in Chinese. Common types: `特性`, `修复`, `文档`, `重构`, `测试`, `样式`. Older history includes `feat:`/`docs:`; prefer the Chinese format going forward.
- PRs should include a concise summary, linked issue (if any), and test/verification notes. Add screenshots or screen recordings for example app UI changes.
