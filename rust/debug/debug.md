## rust编译器调试
主函数在`compiler/rustc/src/main.rs::main`。

### 使用原生GDB

- 进入工作目录
- 使用命令 `gdb /home/lgx/source/rust/rust/build/host/stage1/bin/rustc`
- gdb中运行: r Test.rs

### 使用VSCode
- 新建文件`.vscode/launch.json`
- 添加下面内容

```json
{
    "version": "0.2.0",
    "configurations": [
      {
        "type": "lldb",
        "request": "launch",
        "name": "Debug compiler",
        "args": [], // 传给编译器的参数
        "program": "${workspaceFolder}/build/host/stage1/bin/rustc",
        "windows": {
            "program": "${workspaceFolder}/build/host/stage1/bin/rustc.exe"
        },
        "cwd": "${workspaceFolder}",  //当前工作目录
        "stopOnEntry": false,
        "sourceLanguages": ["rust"]
      }
    ]
  }
```
