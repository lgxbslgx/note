[参考链接](https://llvm.org/docs/MyFirstTypoFix.html)

### 补丁编写过程

- pull主分支的内容，checkout出一个新的分支
- 修改代码和编写测试 edit code
- 重新构建对应的模块，比如 `ninja clang`
- 使用新构建的内容测试之前的demo，比如 `./build/bin/clang test.c`
- 执行该模块所有的测试，比如 `ninja check-clang`
- 执行指定的测试，比如 `./build/bin/llvm-lit -v clang/test/SemaCXX/warn-infinite-recursion.cpp` 或者 `bin/llvm-lit -v ../clang/test/SemaCXX/warn-infinite-recursion.cpp`
- 执行单元测试，比如 `ninja ToolingTests && tools/clang/unittests/Tooling/ToolingTests --gtest_filter=ReplacementTest.CanDeleteAllText`
- 本地提交代码，比如 `git commit -m "[模块名] 修改的内容"`

### review过程
- 从这个 [列表](https://lists.llvm.org/mailman/listinfo) 里面找到对应的订阅邮箱（以`-commits`结尾），比如clang的代码对应的subscriber就是cfe-commits。
- 上传补丁：`arc diff HEAD^`，填写相关信息，最重要的是填写上面找到的subscriber
- 接受comments并修改补丁
- 上传更新后的补丁：`arc diff`
- 补丁被接受（Accept），让其他人帮你提交代码，比如：`Thanks @somellvmdev. I don’t have commit access, can you land this patch for me? Please use “My Name my@email” to commit the change.`
- 如果本人是committer，则可以自己提交，具体流程如下
  - 把补丁的多个commit压缩成单个commit（squash）：`git rebase -i nextUnrelatedCommitHash`
  - 合并远程分支代码：`git pull --rebase https://github.com/llvm/llvm-project.git main`
  - 查看日记看代码是否正常：`git log` `git diff`
  - 再次运行测试，避免出现问题（上文已经提及）
  - 提交代码到远程：`git push https://github.com/llvm/llvm-project.git HEAD:main`

