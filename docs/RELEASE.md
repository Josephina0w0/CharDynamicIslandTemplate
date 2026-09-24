# 构建与发布检查

版本功能、修复和升级注意事项统一维护在仓库根目录的 `CHANGELOG.md`。发布前应先更新版本号、构建号和对应版本段落，再创建同名 Git 标签。

## 本机构建

```sh
./build_app.sh
```

预期生成：

```text
dist/角色效率岛.app
dist/角色效率岛.zip
```

脚本会分别构建 Apple 芯片与 Intel 版本，合并为 Universal 2 应用，再复制资源、生成图标、进行本地临时签名并制作 zip。

## 发布前检查

- 占位角色名、`com.example` Bundle ID 和占位图片都已替换。
- 只包含有权分发的图片、字体和标志。
- `.gitignore` 排除了 `.build`、`dist`、`.DS_Store` 和 zip。
- 工作、休息、待命、喝水、普通提醒、AI 和四条定时提醒都已看过。
- 当日记录和累计记录可见。
- 30 分钟自动待命与恢复工作正常。
- 菜单栏图标能打开、关闭并再次打开控制面板。
- 打包 App 启动后进程持续存在，菜单栏图标实际出现；不能只以“系统曾弹出权限提示”判断启动成功。
- `scripts/verify_universal_app.sh "dist/角色效率岛.app"` 通过。
- `scripts/verify_universal_app.sh "dist/角色效率岛.zip"` 通过。

## 分享给另一台 Mac

优先分享 zip，不要直接通过聊天软件发送裸 `.app` 文件夹。接收者解压后可能需要右键“打开”，并在自己的 Mac 上重新授权输入监控和辅助功能。

本地临时签名不等于 Apple 公证。如果要面向大量用户公开下载，应使用自己的 Apple Developer ID 完成签名和公证。
