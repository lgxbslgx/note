## 安装过程(type-c直接连接)
[官方文档](https://wiki.friendlyelec.com/wiki/index.php/SOM-RK3399v2#Flash_Image_to_eMMC_under_Linux_with_Type-C_Cable)。

需要注意的点:
- 如果是windows ，则是`01_Official images/03_USB upgrade images`里面的image，比如`rk3399-usb-friendlycore-focal-4.19-arm64-20230314.zip`。
- 如果是linux，则是[03_Partition image files](https://drive.google.com/drive/folders/1X4mHwNUl3qXFGv9Bx0QhLy1v7lMyRy4L)的image，不过我本地linux不成功。

- 先长按`power`键关机，之后同时按住`recovery`和`power`键2秒，才能进入`LOADER`模式。

## SD卡安装
- [官方文档](https://wiki.friendlyelec.com/wiki/index.php/SOM-RK3399v2/zh)
- 镜像为: `01_Official images/01_SD card images/rk3399-sd-friendlycore-focal-4.19-arm64-20230314.img.gz` [下载链接](https://drive.google.com/drive/folders/1zGNtAY3g-LGHiRddg0edn5Z50ZIaW1Q4)
- 解压缩: `gunzip rk3399-sd-friendlycore-focal-4.19-arm64-20230314.img.gz`
- 使用`win32diskimager`把解压的镜像`烧录`到TF卡中
- 调整分区大小
```
umount /dev/sdc
sudo parted -l

sudo fdisk /dev/sdc

p // 查看当前分区，记住分区开始的扇区号
d // 删除分区
9 // 删除分区号
d // 删除分区
8 // 删除分区号
n // 新建分区
8 // 新建分区号
start block: // 刚刚记住的分区开始的扇区号
last block: // 直接enter，默认就行
n // 不删除
w // 写回硬盘

sudo resize2fs /dev/sdc8
```
