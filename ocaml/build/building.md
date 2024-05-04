## OCaml构建

```shell
# 下载代码
git clone git@github.com:ocaml/ocaml.git

# 进入目录
cd ocaml

# 配置
./configure --prefix=/home/lgx/install/ocaml

# 构建
make -j 2

# 安装到`--prefix=`指定的目录
make install

# 执行测试
make tests
```
