## 加载和链接
《Linux Kernel Development》没有相关内容
《Linux内核源代码情景分析》4.4 系统调用execve
《Professional Linux Kernel Architecture》没有相关内容
《Understanding the Linux Kernel》
  - 第20章 Program Execution
《程序员的自我修养-链接、装载与库》
《linkers and loaders》


### 数据结构
- `include/linux/binfmts.h::linux_binfmt`执行文件格式
  - `struct list_head lh`链表前后的文件格式
  - `struct module *module` 所在模块
  - `load_binary`函数：判断文件是否满足当前格式要求，满足要求则加载对应的二进制可执行文件（不同文件格式有不同的加载方式）
  - `load_shlib`函数：加载共享库
  - `core_dump`函数：core dump处理函数
  - `min_coredump`：最小的core dump大小

- `include/linux/binfmts.h::linux_binprm`表示一个可执行二进制文件

- `fs/binfmt_elf.c.c::elf_format`ELF文件格式
- `fs/script.c::script_format`脚本语言文件格式（shell、python、perl等）
- `fs/binfmt_elf_fdpic.c::elf_fdpic_format`fdpic文件格式
- `fs/binfmt_misc.c::misc_format`misc文件格式
- `fs/binfmt_flat.c::flat_format`flat文件格式


### 操作
系统调用`execve`执行一个可执行文件

- ELF文件格式
  - 其`load_binary`函数则会加载、解析ELF文件
  - 把ELF文件内容解析后，放到内存中
  - 会重新设置虚拟内存信息，把父进程继承过来的内存信息覆盖掉

- 脚本语言文件格式（shell、python、perl等）
  - 其`load_binary`函数则会打开对应的解释器的ELF文件，放到`linux_binprm::interpreter`中
  - 然后内核会把`linux_binprm::interpreter`赋值给`linux_binprm::file`
  - 再进行解释器的**ELF文件**的加载和解析工作（详见上文）

