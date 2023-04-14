### 第一版
J2SE 1.0
- [JLS 1 1996年 书籍](https://download.oracle.com/otndocs/jcp/jls1-spec/)
- [JVMS 1 1997年 书籍](https://www.cs.miami.edu/home/burt/reference/java/language_vm_specification.pdf)

JVMS1的`8 Threads and Locks`是在JLS1的`17 Threads and Locks`基础上有一点小小的改动。

### 第二版
J2SE 1.2-1.4
- [JLS 2 - JSR 59 - 2000](https://jcp.org/en/jsr/detail?id=59) [JLS 2 download page](http://titanium.cs.berkeley.edu/doc/java-langspec-2.0.pdf) [JLS 2 Online page](https://jcp.org/aboutJava/communityprocess/final/jsr059/index.html)
- [JVMS 2](https://docs.oracle.com/javase/specs/) 最下面的`Java SE6`里面的`The Java Virtual Machine Specification, Second Edition` [Online page](https://docs.oracle.com/javase/specs/jvms/se6/html/VMSpecTOC.doc.html)

`JVMS2`的`8 Threads and Locks`和第一版`JVMS`基本没差别。

J2SE 5.0（注意这里可以说是1.5，只是编号方式改变了）
- [JLS - JSR 176](https://jcp.org/en/jsr/detail?id=176) [JLS download page](https://jcp.org/aboutJava/communityprocess/final/jsr176/index.html)
- [JVMS 5.0](https://jcp.org/aboutJava/communityprocess/maintenance/jsr924/index.html)

[JSR-133](https://jcp.org/en/jsr/detail?id=133)修改了线程模型，并且加到J2SE 5中（JSK-333没有了关于`working memory`的描述）。为了避免重复，虚拟机规范里的线程模型`8 Threads and Locks`相关内容就删除了，**只放在Java语言规范里**。


### 第三版
Java SE 6
- [JLS 6 - JSR 270](https://jcp.org/en/jsr/detail?id=270) [JLS 6 download page](https://docs.oracle.com/javase/specs/) [JLS 6 PDF](https://docs.oracle.com/javase/specs/jls/se6/jls3.pdf)
- [JVMS 6.0](https://jcp.org/aboutJava/communityprocess/maintenance/jsr924/index2.html) 修改的内容很少，没有完整文档，看第二版就行。


### Java SE 7之后
Oracle官网、OpenJDK官网、JCP官网都整理了
- [JCP官网](https://jcp.org/en/jsr/all) 搜索`Release Contents`和/或`Java™ SE `即可看到所有JLS。
- [Oracle官网](https://docs.oracle.com/en/java/javase/) [Oracle官网-规范](https://docs.oracle.com/javase/specs/) 
- [OpenJDK官网](https://jcp.org/en/jsr/all)

