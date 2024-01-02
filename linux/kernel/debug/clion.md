## 使用Clion
[Clion Compilation database](https://www.jetbrains.com/help/clion/compilation-database.html)
[创建compile_commands.json](https://github.com/habemus-papadum/kernel-grok)

- 安装`pip`。`sudo apt install python3-pip`
- 安装`scan-build`。`pip install scan-build --user`
- 创建`compile_commands.json`。`~/.local/bin/intercept-build make -j 2`
- 使用Clion打开`compile_commands.json`即可。
  - `File` -> `Open`
  - `选择刚刚生成的compile_commands.json`
  - `选择 Open As Project`
