64bit:
https://github.com/azul-research/jdk-riscv/blob/riscv/dev-riscv/docs/CROSS_COMPILING.md
https://github.com/azul-research/jdk-riscv/blob/riscv/dev-riscv/toolchain/Dockerfile
https://github.com/isrc-cas/bishengjdk-11-mirror/blob/risc-v/BUILDING.md
https://github.com/isrc-cas/bishengjdk-11-mirror/blob/risc-v/DEPENDENCY_BUILD.md

32bit:
https://github.com/openjdk-riscv/jdk11u/wiki/Build-OpenJDK11(zero-VM)-for-RV32G
https://github.com/openjdk-riscv/jdk11u/wiki/External-Libraries
https://zhuanlan.zhihu.com/p/372067562
https://zhuanlan.zhihu.com/p/344502147


export PATH=/opt/riscv/bin/:$PATH
export sysroot=/opt/riscv/sysroot
export prefix=$sysroot/usr
echo $sysroot
echo $prefix

找不到命令就设置环境变量PATH

aclocal找不到.m4文件，就设置 AL_L_OPTS=-I/usr/share/aclocal

x11库:
复制.m4文件，或者反向复制
cp /usr/share/aclocal/*.m4 /usr/local/share/aclocal/

cups库:
# 把configure文件里面的-Werror删了

