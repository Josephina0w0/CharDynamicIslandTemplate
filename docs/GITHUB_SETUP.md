# GitHub 发布

本仓库应只提交源码、文档、SVG 模板和占位 PNG，不提交本地记录、`.build`、`dist` 或打包 zip。

```sh
git init
git add .
git commit -m "Initial clean character efficiency island template"
git branch -M main
git remote add origin https://github.com/YOUR_NAME/CharDynamicIslandTemplate.git
git push -u origin main
```

如果使用 GitHub Desktop，可以选择“Add Existing Repository”，选中本文件夹，再点击 Publish repository。发布前确认仓库可见性和素材授权。

建议为每个发布版本创建独立标签，并把对应的 `dist/角色效率岛.zip` 作为 GitHub Release 附件，而不是提交进 Git 历史。发布 0.1.3 和 0.1.4 时应分别使用 `v0.1.3`、`v0.1.4`，不要让两个标签指向同一份源码。
