### GNU Libc
- [GNU](https://www.gnu.org)
- [glibc](https://www.gnu.org/software/libc)
- [mail list](https://www.gnu.org/software/libc/involved.html) is like OpenJDK
- [bug tracker](https://sourceware.org/bugzilla/buglist.cgi?bug_status=UNCONFIRMED&bug_status=NEW&bug_status=ASSIGNED&bug_status=SUSPENDED&bug_status=WAITING&bug_status=REOPENED&list_id=57048&product=glibc&query_format=advanced)

#### build and test
- source dir:	~/source/c/glibc  or  /home/lgx/source/c/glibc
- enter dir:	`cd ~/source/c/glibc`
- make dir:		`mkdir glibc-build` `mkdir glibc-install`
- enter dir:	`cd glibc-build`
- configure:	`../configure --prefix=/home/lgx/source/c/glibc/glibc-install`
- make:			`make -j2`
- 生成`compile_commands.json`: `~/.local/bin/intercept-build make -j2`
- 软链接: `ln -s /home/lgx/source/c/glibc/glibc-build/compile_commands.json /home/lgx/source/c/glibc/compile_commands.json`

- test:			`make check`
- Reference Manual:	`make dvi`
- rewrite config in file `configparms`
- install: 		`make install`  
