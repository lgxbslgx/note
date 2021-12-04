## 使用git diff显示的数据分析
- 命令 `git -c core.quotePath=false diff --cached  --patch --find-copies-harder --binary --raw`


### 类型
- 新增 Add(A)
- 修改 Modify(M)
- 删除 Delete(D)
- 改名 Rename(R90) R后面的数字是修改百分比
- 复制 Copy(C90) C后面的数字是修改百分比
- 需要处理合并 Unmerged

```
修改类型 ：源文件类型 目标文件类型 源文件hash 目标文件hash 修改类型缩写 源文件路径 目标文件路径
in-place edit  :100644 100644 bcd1234 0123456 M file0
copy-edit      :100644 100644 abcd123 1234567 C68 file1 file2
rename-edit    :100644 100644 abcd123 1234567 R86 file1 file3
create         :000000 100644 0000000 1234567 A file4
delete         :100644 000000 1234567 0000000 D file5
unmerged       :000000 000000 0000000 0000000 U file6
```

### Binary文件
- 新增文件 Modify(M)

```
:000000 100644 0000000 c9eef64 A        1.png

diff --git a/1.png b/1.png
new file mode 100644
index 0000000000000000000000000000000000000000..c9eef647c05835cff73f2bc294517bc6dfc18161
GIT binary patch
literal 118
zcmeAS@N?(olHy`uVBq!ia0vp^AT}2V6Od#Ih<F90I14-?iy0WWg+Z8+Vb&Z8pdfpR
zr>`sfQyvyRN%NO)s&4^>L_J*`LnJOI|M~ylo;mNpkp}UekW7Z9kC_GkU$EQ>RKVcr
L>gTe~DWM4fWGWtH

literal 0
HcmV?d00001
```

- 复制文件 Copy(C90) C后面的数字是修改百分比

```
:100644 100644 c9eef64 c9eef64 C100     1.png   t/1.png

diff --git a/1.png b/t/1.png
similarity index 100%
copy from 1.png
copy to t/1.png
```

- 重命名 Rename(R90) R后面的数字是修改百分比

```
:100644 100644 c9eef64 c9eef64 R100     t/1.png t/2.png

diff --git a/t/1.png b/t/2.png
similarity index 100%
rename from t/1.png
rename to t/2.png
```

- 修改 Modify(M) 第一个文件加了4个字符，第2个文件加了8个字符。

```
:100644 100644 c9eef64 0000000 M        1.png
:100644 100644 c9eef64 0000000 M        t/2.png

diff --git a/1.png b/1.png
index c9eef647c05835cff73f2bc294517bc6dfc18161..92ba0849167c5c8e8568ab7ab7f0a1cd6354af51 100644
GIT binary patch
delta 10
RcmXS`o>0b`Se%x^1ppR?1El}}

delta 4
Lcmb;}n@|P-1n2?y

diff --git a/t/2.png b/t/2.png
index c9eef647c05835cff73f2bc294517bc6dfc18161..e686d50e2da17689569ac0aac4c2abfa40a4d9b4 100644
GIT binary patch
delta 14
ScmXS`pHRk`Se%ju!dw6<^#w}+

delta 4
Lcmb;~n@|P-1o#2`
```

- 删除 Delete(D)

```
:100644 000000 1664853 0000000 D        1.png

diff --git a/1.png b/1.png
deleted file mode 100644
index 1664853445ec6ffad5c4e98027695f9184ef0297..0000000000000000000000000000000000000000
GIT binary patch
literal 0
HcmV?d00001

literal 123
zcmeAS@N?(olHy`uVBq!ia0vp^AT}2V6Od#Ih<F90I14-?iy0WWg+Z8+Vb&Z8pdfpR
zr>`sfQyvyRN%NO)s&4^>L_J*`LnJOI|M~ylo;mNpkp}UekW7Z9kC_GkU$EQ>RKVcr
Q>gTe~DWNH`I3<k>00H123;+NC
```
