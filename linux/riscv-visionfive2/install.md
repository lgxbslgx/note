## 安装
[官方文档](https://doc-en.rvspace.org/VisionFive2/Quick_Start_Guide/VisionFive2_QSG/flashing_with_mac_linux.html)

[image下载链接](https://debian.starfivetech.com/)

- 要使用目录`engineering release/202303`里面的镜像。
  - 目录`engineering release/202302/sd`的镜像不能远程连接。
  - 目录`engineering release/image-69`的镜像直接不行，`engineering release/image-69/minimal`的镜像不能远程连接。

SD卡的分区有问题，只有2-3G的内容可用:
- 如果SD当前存储未满，且系统里面有下面的命令，则在系统里直接运行下面命令。否则，把SD卡插入自己电脑，运行下面命令。
- 使用`df -h`看到只有2-3G（直接使用`fdisk`操作不行）
- **使用`sudo parted -l`，再`fix`**
- 这时候再使用`fdisk`进行分区，如下

```
sudo fdisk /dev/mmcblk1
// 如果是自己电脑，则是
sudo fdisk /dev/sdc

d // 删除分区
4 // 删除分区号
n // 新建分区
4 // 新建分区号
start block: // 直接enter，默认就行
last block: // 直接enter，默认就行（这里的大小已经被前面的`sudo parted -l`修正过了）
n // 不删除
w // 写回硬盘
```

- 最后运行`sudo resize2fs /dev/mmcblk1p4`就可以了（如果在自己电脑则是`sudo resize2fs /dev/sdc4`）


## 设置无线网络
- 修改文件`sudo nano /etc/network/interfaces`
```
#setup network for starfive eth0
allow-hotplug end0
#iface eth0 inet dhcp

#setup network for starfive eth0
allow-hotplug end1
#iface eth1 inet dhcp

allow-hotplug wlx2c0547a11b58
```

- `ip addr`查看ip
- `nmcli device`查看设备
- `sudo nmcli radio wifi on`开启wifi
- `sudo nmcli device wifi connect 2801-0 password XXXXX`连接某个wifi，`2801-0`换成具体wifi名，`XXXXX`换成具体的wifi密码
- `sudo nmcli device up wlx2c0547a11b58`启动网卡
- `sudo nmcli connection up 2801-0`启动一个连接，`2801-0`换成具体connection名（最好用`sudo nmcli device up wlx2c0547a11b58`，因为connection名每次都可能不同）

## 开机自动连接wifi
新建文件`/etc/init.d/wifi`，输入内容
```
#!/bin/sh
nmcli device wifi connect 2801-0 password 13824508292
nmcli device up wlx2c0547a11b5
```

注意机器不一定连接`2801-0`，它会连接之前连过的wifi中信号最强的那个，也可以说是哪个距离近就连哪个。

**记住: 登录的设备和嵌入式设备要在同一个局域网，要不然很慢而且有时候不行**

## sudo命令很慢
修改文件`/etc/hosts`，`sudo vim /etc/hosts`，添加:
```
127.0.0.1       starfive
# 127.0.0.1     主机名
# 主机名可以根据文件`/etc/hostname`获取
```
修改文件`/etc/ssh/ssh_config`，`sudo vim /etc/ssh_config`，设置:
```
UseDNS no
GSSAPIAuthentication no
```

## 添加apt源

```shell
deb https://ftp.debian.org/debian trixie main
```
