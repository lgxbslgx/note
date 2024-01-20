## glibc中系统调用相关内容
只涉及x86的内容，其他架构应该也差不多。

### X86-64的系统调用
主要使用指令`syscall`进行系统调用，6个参数按顺序放在寄存器`rdi、rsi、rdx、r10、r8、r9`中。

- 文件`sysdeps/unix/sysv/linux/x86_64/sysdep.h`里面有对于系统调用的宏定义`INTERNAL_SYSCALL`和`internal_syscall<N> // N为0-6，表示0-6个参数`。
- 文件`sysdeps/unix/sysv/linux/sysdep.h`里面的宏`INLINE_SYSCALL`使用宏`INTERNAL_SYSCALL`完成系统调用操作。
- 文件`sysdeps/unix/sysdep.h`里面的宏`INLINE_SYSCALL_CALL`使用宏`INLINE_SYSCALL`来完成系统调用操作。

对应的源代码会使用`INLINE_SYSCALL`或`INLINE_SYSCALL_CALL`来完成一个系统调用。比如
- 函数`sysdeps/unix/sysv/linux/read_nocancel.c::__read_nocancel`使用`INLINE_SYSCALL_CALL`调用系统调用`read`
- 函数`sysdeps/unix/sysv/linux/reboot.c::reboot`使用`INLINE_SYSCALL`调用系统调用`reboot`

注意使用这些宏的时候，提供系统调用名称而不是系统调用编号，宏`sysdeps/unix/sysv/linux/x86_64/sysdep.h::SYS_ify`会把`__NR_`和系统调用名称连接起来，然后在`sysdeps/unix/sysv/linux/x86_64/64/arch-syscall.h`获取系统调用号。

### X86-32的系统调用
主要使用指令`int $0x80`，详细内容未看。

