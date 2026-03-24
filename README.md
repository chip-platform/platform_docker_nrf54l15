## 简介
构建编译NRF54L15芯片的环境，此镜像会发布到:
1. `腾讯云`镜像仓库。
2. `GitHub Packages`的镜像仓库。

## 镜像包
基础镜像: ubuntu24.04
基础镜像之上的安装:
* 在基础镜像的基础上增加了`NCS`编译工具.
* 安装如下软件:
```shell
apt-get update \
    && apt-get install -y sudo gcc libc6-dev make srecord git \
    wget python3 python3-pip pipx zip unzip p7zip-full pigz
```

## 脚本使用
### 帮助信息
```shell
./build.sh -h
```
打印脚本的帮助信息。

### 拉取镜像到本地
```shell
./build.sh -l
```
此操作会从私有仓库拉取镜像到本地。
### 保存镜像为tar包
```shell
./build.sh -s
```
执行完成后再`out`目录下生成了本地镜像的tar包。
### 删除本地的所有镜像的tag
```shell
./build.sh -c
```
此操作会将本地所有镜像的tag删除。

## 本地镜像操作
### 制作本地镜像
执行如下指令制作本地镜像:
```shell
./build.sh -c -s
```
### 获取镜像(本地导入)
执行如下的指令，将此本地镜像导入:
```shell
cd out
docker load  -i nrf54l15_<版本>_docker.tar.gz
```
## 进入镜像
导入镜像完成后，就需要启动在编译时启动镜像了:
```shell
docker run -it --rm --name=nrf54l15 nrf54l15:<版本>
```