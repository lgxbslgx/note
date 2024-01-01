下面方法好像没用，直接设置不让ubuntu休眠暂时避免了这个问题。

Ubuntu休眠后无法唤醒黑屏的解决方案

- 安装laptop mode `sudo apt install laptop-mode-tools`
- 判断系统是否使用了laptop mode `cat /proc/sys/vm/laptop_mode`。结果为0，则说明未启用。
- 修改配置文件`/etc/default/acpi-support`的`ENABLE_LAPTOP_MODE`为`true`
- 如果配置文件`/etc/default/acpi-support`找不到`ENABLE_LAPTOP_MODE`，则修改配置文件`/etc/laptop-mode/laptop-mode.conf`
  - `ENABLE_LAPTOP_MODE_ON_BATTERY=1`
  - `ENABLE_LAPTOP_MODE_ON_AC=1`
  - `ENABLE_LAPTOP_MODE_WHEN_LID_CLOSED=1`
- 启动laptop mode `sudo laptop_mode start`

