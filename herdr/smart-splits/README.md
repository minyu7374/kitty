# Herdr / smart-splits v3

此目录同时提供 Herdr 导航插件和 Neovim 的 `smart-splits-backend-herdr` 后端。
两套 Neovim 配置共用这一份实现，无需保留 smart-splits v2。

## 安装

安装 Herdr、Neovim ≥ 0.11 和 `jq`，从 Kitty 配置仓库执行：

```sh
bash herdr/install.sh
```

安装器将本目录链接到 `${XDG_DATA_HOME:-$HOME/.local/share}/smart-splits-herdr`，
并用 `herdr plugin link` 注册导航插件。保持 `smart-splits.nvim` 插件 ID，
现有 `smart-splits.nvim.left/down/up/right` 绑定无需更名。
把 `herdr/workspace-management.toml` 合并到 Herdr 配置；重启 Neovim 加载本地后端。
Kitty 中同时安装 `herdr_keys.py` 和 `splits.conf`；按键入口将当前 socket 和窗口 ID 写入
`${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/smart-splits-herdr-kitty`，
避免重新附着时使用 Herdr 服务端保留的旧 Kitty 连接。
远程 Herdr 主机也需安装本目录，可单独执行安装器，无需安装 Kitty。

## 行为

- Ctrl+h/j/k/l 优先操作 Vim/Neovim 分屏，到边缘时交给 Herdr。
- Herdr 内有邻接面板时优先切换；到边缘后继续切换外层 Kitty 窗口，Shell 和 Neovim 使用相同顺序。
- Shell 在 Herdr 和 Kitty 对应方向都没有邻居时保留原按键，例如 Ctrl+l 清屏。
- Neovim 的 Alt+h/j/k/l 在占满对应轴时缩放 Herdr 分隔线；按父分屏尺寸把字符数换成比例。
- Herdr 后端不主动环绕或创建面板；边缘行为交给 Neovim 的 `move.at_edge`。
- `<C-\>` 在直连 Kitty、tmux 的 Neovim 中返回上一个编辑器窗口；Herdr 保留其原有“上一个面板”绑定。
- Neovim 后端的单次 CLI 调用限定 500 ms；不可达或返回异常时交还控制权。运行 `:checkhealth smart-splits` 检查后端。

Herdr 脚本和 manifest 来自 smart-splits.nvim v2，许可证见 [LICENSE](LICENSE)。

## 验证

在仓库根目录执行；`SMART_SPLITS_DIR` 指向已安装的 smart-splits v3：

```sh
HERDR_BACKEND_DIR="$PWD/herdr/smart-splits" SMART_SPLITS_DIR=/path/to/smart-splits.nvim \
  nvim --headless -u NONE -i NONE -l herdr/smart-splits/tests/backend.lua
python3 -m unittest discover -s herdr/smart-splits/tests
KITTY_SPLITS_DIR="$PWD" kitty +runpy 'import runpy; runpy.run_path("tests/test_relative_resize.py", run_name="__main__")'
```
