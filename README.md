<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [服务介绍](#服务介绍)
- [运行环境](#运行环境)
- [配置管理](#配置管理)
- [项目依赖](#项目依赖)
	- [当前依赖](#当前依赖)
	- [候选依赖](#候选依赖)
		- [如果使用`libmagick`方案](#如果使用libmagick方案)
		- [如果使用`gm`方案](#如果使用gm方案)
- [部署](#部署)
	- [安装依赖](#安装依赖)
	- [nginx编译](#nginx编译)
	- [模块编译](#模块编译)
	- [发布部署](#发布部署)
		- [发布平台脚本](#发布平台脚本)
		- [注意点](#注意点)
	- [部署过程中可能遇到的问题及处理方法](#部署过程中可能遇到的问题及处理方法)
		- [问题 - pcre没装](#问题-pcre没装)
		- [问题 - perl没装](#问题-perl没装)
		- [问题 - perl module ExtUtils::Embed is required](#问题-perl-module-extutilsembed-is-required)
- [运行](#运行)
- [Benchmark](#benchmark)

<!-- /TOC -->



# 服务介绍
基于nginx-lua-opencv-gifsicle的缩略图方案，目前限定为bfs配套服务。通过http（nginx upstream）获取bfs后台原图进行缩略返回请求方。
对于gif图片，使用gifsicle方案； 对于非gif方案，使用opencv方案。


# 运行环境
* Debian version 8.2  
* Lua 5.1/LuaJIT-2.0.3  
* Nginx 1.8.1  
* Tengine/2.1.2 (nginx/1.9.7)    
* opencv 2.4.9
* gifsicle 1.86-1


# 配置管理
目前项目用到的配置只有nginx配置，都在`nginx`目录下，不同环境的配置则在`nginx/site-enables`中，命名方式为`${env}-${level}.conf`，如： `shd-http.conf`。
配置文件类型如下：
* global.conf
> nginx global级别配置，目前主要是 worker数和CPU亲缘性
* http.conf
> nginx http级别配置，目前主要是bfs upstream
* server.conf
> nginx server级别配置，目前主要是监听端口

# 项目依赖

## 当前依赖
* nginx
> 1.9.7，至今（2016-05-16）为止，lua-nginx-module只支持到这个版本
> 编译： `./configure --prefix=/usr/local/nginx --with-debug --with-http_addition_module --with-http_dav_module --with-http_gzip_static_module --with-http_perl_module --with-http_realip_module --with-http_secure_link_module --with-http_ssl_module --add-module=/data/app/thumbnail/nginx/module/ngx_devel_kit --add-module=/data/app/thumbnail/nginx/module/lua-nginx-module --add-module=/data/app/thumbnail/nginx/module/ngx_cache_purge`
> **prefix可以根据实际需要进行调整； module目录跟项目代码目录有关；**
* nginx modules
> 在代码目录`nginx/module`中，编译nginx时指定即可
  * ngx_devel_kit
  * lua-nginx-module
  * ngx_cache_purge
* lua
> 5.1，luajit至今（2016-05-16）只支持到lua5.1
> `aptitude install -y lua5.1 liblua5.1-dev`
> 注意so路径问题
* luajit
> `aptitude install -y libluajit-5.1-dev`
* opencv
> `aptitude install -y libopencv-dev libopencv-core2.4 libopencv-core-dev python-opencv`
* gifsicle
> `aptitude install -y gifsicle`
> 如果没有的话则自行编译安装：
```shell
cd /data/sw
wget https://www.lcdf.org/gifsicle/gifsicle-1.88.tar.gz
tar xzf gifsicle-1.88.tat.gz
cd gifsicle
./configure
make && make install
```

## 候选依赖

### 如果使用`libmagick`方案
* libmagickwand
> `aptitude install -y libmagickwand-dev`
* lua库magick
> `aptitude install -y luarocks`
> `luarocks install magick`  

### 如果使用`gm`方案
* graphicsmagick
> `aptitude install -y graphicsmagick`

# 部署

## 安装依赖
参见前面依赖部分

## nginx编译

1. 下载nginx
```shell
mkdir /data/sw
cd /data/sw
wget 'http://nginx.org/download/nginx-1.9.7.tar.gz'
# worker_cpu_affinity auto; 需要1.9.10 +
# 但lua nginx只支持到1.9.7，晕死
tar xzf nginx-1.9.7.tar.gz
cd nginx-1.9.7
```
2. 编译nginx（需要依赖luajit已经安装）
```shell
./configure --prefix=/usr/local/nginx --with-debug --with-http_addition_module --with-http_dav_module --with-http_gzip_static_module --with-http_perl_module --with-http_realip_module --with-http_secure_link_module --with-http_ssl_module --add-module=/data/app/thumbnail/nginx/module/ngx_devel_kit --add-module=/data/app/thumbnail/nginx/module/lua-nginx-module --add-module=/data/app/thumbnail/nginx/module/ngx_cache_purge`
# prefix可以根据实际需要进行调整； module目录跟项目代码目录有关；
```

## 模块编译
```shell
# 只测试过linux平台
# 需要确认lua的so文件路径正确
ld -llua --verbose
dpkg -L liblua5.1-0-dev
ln -s /usr/lib/x86_64-linux-gnu/liblua5.1.so.0.0.0 /usr/lib/x86_64-linux-gnu/liblua.so  # 跟实际路径可能有关
cd lua-opencv
make linux
```

## 发布部署
1. 【新机器部署】按照前面的要求，安装好依赖
2. 确认项目需要的目录已经创建，主要是 `/data/thumbnail/www`
3. 执行发布

### 发布平台脚本
* 发布前执行
  ```shell
  if [ ! -d "/data/logs/thumbnail" ];then
   mkdir -p /data/logs/thumbnail
  fi
  ```
* 发布后执行
  ```shell
  cd /data/app/thumbnail/lua-opencv && make clean && make linux

  cp /data/app/thumbnail/nginx/site-enables/${thumbnail_env}-global.conf /data/app/thumbnail/nginx/site-enables/global.conf  
  cp /data/app/thumbnail/nginx/site-enables/${thumbnail_env}-http.conf /data/app/thumbnail/nginx/site-enables/http.conf
  cp /data/app/thumbnail/nginx/site-enables/${thumbnail_env}-server.conf /data/app/thumbnail/nginx/site-enables/server.conf

  /usr/local/nginx/sbin/nginx -c /data/app/thumbnail/nginx/nginx.conf -t || exit 200
  /usr/local/nginx/sbin/nginx -c /data/app/thumbnail/nginx/nginx.conf -s reload
  ```
  > ${thumbnail_env}要么写死，要么依赖环境变量

### 注意点
* **因为nginx CPU亲缘性配置写死了，所以一个环境的各台机器CPU数要一致，并且如果有变化，需要跟配置文件核对**
> nginx1.9.10版本才允许配置亲缘性为auto

## 部署过程中可能遇到的问题及处理方法

### 问题 - pcre没装

表现：
```
adding module in /data/apps/src/thumbnail/nginx/module/ngx_cache_purge
 + ngx_http_cache_purge_module was configured
checking for PCRE library ... not found
checking for PCRE library in /usr/local/ ... not found
checking for PCRE library in /usr/include/pcre/ ... not found
checking for PCRE library in /usr/pkg/ ... not found
checking for PCRE library in /opt/local/ ... not found

./configure: error: the HTTP rewrite module requires the PCRE library.
You can either disable the module by using --without-http_rewrite_module
option, or install the PCRE library into the system, or build the PCRE library
statically from the source with nginx by using --with-pcre=<path> option.
```

解决：
```shell
aptitude install -y libpcre3-dev libssl-dev openssl
```

### 问题 - perl没装
```shell
aptitude install -y libperl-dev
ld -lperl --verbose 可以查看是否可用
```

### 问题 - perl module ExtUtils::Embed is required

表现：
```
rh - ./configure: error: perl module ExtUtils::Embed is required
```

解决：
```shell
yum -y install perl-devel perl-ExtUtils-Embed
```

# 运行
`/usr/local/nginx/sbin/nginx -c /data/thumbnail/nginx/nginx.conf`


# Benchmark
8 CPU 2.4G, 8G RAM, Debian 8.2    
2787.6 fetches/sec, 1.12597e+07 bytes/sec   
