# 「说人话」构建与发布

## 当前事实

- 用户版本来源：`Info.plist` → `CFBundleShortVersionString`。
- 当前目标：Apple Silicon、macOS 13 及以上。
- `./scripts/build.sh` 生成本地 `.app`，当前使用 ad-hoc 签名，仅用于功能验证。
- 公开下载仓库是 `lydiahub19921013/shuorenhua`；本私有源码仓库不自动发布任何文件。

## 本地验证

```bash
./scripts/test.sh
./scripts/build.sh
```

测试必须全部通过。构建后核对：

```bash
plutil -p build/v<version>/说人话.app/Contents/Info.plist
codesign --verify --deep --strict build/v<version>/说人话.app
```

通过这些检查只能说明本地功能验证构建成立，不代表 Developer ID 签名、公证、Gatekeeper 或客户环境已经通过。

## 对外交付门禁

1. 工作树中的发布源码已经提交，记录完整 40 位提交哈希。
2. `./scripts/test.sh` 全部通过。
3. 从同一提交构建最终应用。
4. 正式直接分发时使用 Developer ID Application 签名并完成 Apple 公证与 stapling；缺少条件时只能标记为 ad-hoc 功能验证包。
5. 对最终 ZIP 计算 SHA-256，记录版本、架构、签名、公证及测试状态。
6. 用一条真实用户路径验证主动取词、理解、行动拆解、按原意回复、承诺检查和放回输入框；无法确认输入框时必须安全退化为复制。
7. 只有得到明确发布授权，才能更新公开仓库和 GitHub Release。

发布包、截图和签名材料不提交到私有源码 Git 历史；它们使用受控的本地交付目录和公开下载仓库管理。
