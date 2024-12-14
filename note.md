# 一些重要功能的记录

## Sample kitty.conf

```bash
kitty +runpy 'from kitty.config import *; print(commented_out_default_config())'
```

## Transfer files

> https://sw.kovidgoyal.net/kitty/kittens/transfer/

下载
```bash
<local computer>  $ kitten ssh my-remote-computer
<remote computer> $ kitten transfer some-file /path/on/local/computer
```

上传
```bash
<local computer>  $ kitten ssh my-remote-computer
<remote computer> $ kitten transfer --direction=upload /path/on/local/computer remote-file
```
多个文件/文件夹
```bash
kitten transfer file1 file2 /path/to/dir/
kitten transfer dir1 /path/to/dir/
```

## kitten hint

> https://sw.kovidgoyal.net/kitty/kittens/hints/

```plain
ctrl+shift+p>f
ctrl+shift+p>n
ctrl+shift+p>y
```

## kitten clipboard

https://sw.kovidgoyal.net/kitty/kittens/clipboard/

从shell脚本几乎可以将任意数据流复制到系统剪贴板

```
echo hooray | kitten clipboard
kitten clipboard picture.png
```
