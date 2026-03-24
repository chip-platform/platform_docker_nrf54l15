FROM ubuntu:24.04
#########################################################
# 注意点:
#   1. ubuntu默认会创建一个ubuntu用户,需要先删除
#   2. 创建的镜像的用户名和WSL下的用户名一致
#   3. 保证用户名的UID和GID与WSL下的一致
#########################################################
# ncs的版本
ARG NCS_VERSION=v3.3.0-preview3
# 用户名,需要和本地的用户名一致
ARG USER_NAME=wangyan
ARG USER_PWD=123456
ARG USER_ID=1000
# 导入repo
COPY repo /usr/local/bin/

# 更新apt的源码
RUN echo "Types: deb" > /etc/apt/sources.list.d/ubuntu.sources \
    && echo "URIs: http://mirrors.tuna.tsinghua.edu.cn/ubuntu/" >> /etc/apt/sources.list.d/ubuntu.sources \
    && echo "Suites: noble noble-updates noble-security" >> /etc/apt/sources.list.d/ubuntu.sources \
    && echo "Components: main restricted universe multiverse" >> /etc/apt/sources.list.d/ubuntu.sources \
    && echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" >> /etc/apt/sources.list.d/ubuntu.sources

# 安装软件
RUN apt update \
    && apt upgrade -y \
    && apt install -y sudo gcc libc6-dev make srecord git \
    wget python3 python3-pip pipx zip unzip p7zip-full pigz gzip

#########################################################
# NCS的配置
#########################################################
# NCS的安装目录
ARG NCS_INSTALL_DIR=/opt/${NCS_VERSION}
COPY ${NCS_VERSION}.7z /opt/toolchain.7z
# 设置NCS工具链变量
RUN 7z x /opt/toolchain.7z -o/opt/

# 设置工具链环境变量
ENV LD_LIBRARY_PATH=${NCS_INSTALL_DIR}/usr/lib:${NCS_INSTALL_DIR}/usr/lib/x86_64-linux-gnu:${NCS_INSTALL_DIR}/usr/local/lib
ENV PYTHONHOME=${NCS_INSTALL_DIR}/usr/local
ENV PYTHONPATH=${NCS_INSTALL_DIR}/usr/local/lib/python3.12:${NCS_INSTALL_DIR}/usr/local/lib/python3.12/site-packages
ENV ZEPHYR_SDK_INSTALL_DIR=${NCS_INSTALL_DIR}/opt/zephyr-sdk
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV NRFUTIL_HOME=${NCS_INSTALL_DIR}/nrfutil/home
ENV PATH="${NCS_INSTALL_DIR}/usr/bin":$PATH
ENV PATH="${NCS_INSTALL_DIR}/usr/local/bin":$PATH
ENV PATH="${NCS_INSTALL_DIR}/opt/bin":$PATH
ENV PATH="${NCS_INSTALL_DIR}/opt/nanopb/generator-bin":$PATH
ENV PATH="${NCS_INSTALL_DIR}/nrfutil/bin":$PATH
ENV PATH="${NCS_INSTALL_DIR}/opt/zephyr-sdk/arm-zephyr-eabi/bin":$PATH
ENV PATH="${NCS_INSTALL_DIR}/opt/zephyr-sdk/riscv64-zephyr-elf/bin":$PATH
ENV PATH="/home/${USER_NAME}/.local/bin":$PATH

#########################################################
# 用户配置
#########################################################
# 添加用户：赋予sudo权限，指定密码
RUN useradd --create-home --no-log-init --shell /bin/bash ${USER_NAME} \
    && adduser ${USER_NAME} sudo \
    && echo "${USER_NAME}:${USER_PWD}" | chpasswd

# 改变用户的UID和GID
RUN userdel ubuntu \
    && usermod -u ${USER_ID} ${USER_NAME} && groupmod -g ${USER_ID} ${USER_NAME}

# 指定容器起来的登录用户
USER ${USER_NAME}

# 更改挂在目录的权限
RUN chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME} -R \
    && chmod 755 /home/${USER_NAME} -R

# 修改工作目录
WORKDIR /home/${USER_NAME}/
# 默认执行的指令
CMD ["bash"]
