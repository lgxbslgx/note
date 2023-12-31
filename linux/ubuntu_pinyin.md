ubuntu安装拼音输入法

- 安装输入法框架fcitx `sudo apt install fcitx`
- 添加中文语言 `Setting -> Region&Language -> Manage Install Languages -> install/Remove Languages -> select Chinese(simplified)`
- 选择输入法框架fcitx `Setting -> Region&Language -> Manage Install Languages -> keyboard input method system -> select fcitx`
- 全局应用 `Setting -> Region&Language -> Manage Install Languages -> Apply System-wide`
- 设置fcitx开机自启动 `sudo cp /usr/share/applications/fcitx.desktop /etc/xdg/autostart/`
- 卸载系统ibus输入法框架 `sudo apt purge ibus`
- 安装搜狗输入法
  - 下载链接 `https://shurufa.sogou.com/linux/guide`
  - 安装 `sudo dpkg -i sogoupinyin_版本号_amd64.deb`
- 安装输入法依赖（**这一步非常重要，不能忽略**）
  - `sudo apt install libqt5qml5 libqt5quick5 libqt5quickwidgets5 qml-module-qtquick2`
  - `sudo apt install libgsettings-qt1`
- 重启操作系统

