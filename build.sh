#!/bin/bash
###################################################################
# 参数使用帮助:
#   1. -l: 拉取此镜像到本地
#   2. -s: 保存此镜像到本地
#   3. -c: 删除本地镜像
#   4. -h: 打印帮助信息
###################################################################
# 镜像版本,这里是以SDK版本
version=v3.3.0-preview3
# 腾讯仓库命名空间
docker_tencent_registry_namespace="chip_platform"
# 腾讯仓库名称
docker_tencent_registry_name="nrf54l15"
# 腾讯仓库登录地址
docker_tencent_registry_url="sgccr.ccs.tencentyun.com"
# 腾讯仓库登录username
docker_tencent_registry_username=""
# 腾讯仓库登录password
docker_tencent_registry_password=""
# github仓库命名空间
docker_github_registry_namespace="chip-platform"
# github仓库名称
docker_github_registry_name="platform_docker_nrf54l15"
# github仓库地址
docker_github_registry_url="ghcr.io"

# 拉取的类型
docker_pull_type_name_arry=(
    "tencent: 腾讯云"
    "github: github"
)

# 默认目标
docker_pull_type_name=`echo ${docker_pull_type_name_arry[0]} |awk -F ':' '{print $1}'`

###################################################################
# 打印配置
###################################################################
die() {
	echo -e "\033[31m ERROR: $@ \033[0m"
	exit 1
}

log() {
    echo -e "\033[32m LOG: $@ \033[0m"
}

##########################################
# 判定docker指令是否存在
##########################################
docker_path=$(command -v docker)

if [ -z ${docker_path} ]; then
    die "docker is not install!"
fi

###################################################################
# 临时全局变量
###################################################################
# 当前目录
cd $(dirname "$0")
local_path=`pwd`

build_dir=${local_path}/build
out_dir=${local_path}/out
resource_dir=${local_path}/resource

###################################################################
# 打印使用
###################################################################
# 打印使用
args_help() {
    log "***********************************************************"
    log "* ./build.sh -l: 拉取此镜像到本地"
    log "* ./build.sh -s: 保存此镜像到本地"
    log "* ./build.sh -c: 删除本地所有版本镜像"
    log "***********************************************************"
}

###################################################################
# 判定镜像是否存在
# 参数1: docker镜像名称
# 0: 不存在
# 1: 存在
###################################################################
docker_check_is_image(){
    docker_image_name="$1"
    # 查找镜像
    if docker image ls --format "{{.Repository}}" | sort -u | grep -wq "$docker_image_name"; then
        log "✅ 镜像 ${docker_image_name} 是存在的"
        return 1
    else
        log "❌ 镜像 ${docker_image_name} 是不存在的"
        return 0
    fi
}

###################################################################
# 判定特定版本镜像是否存在
# 参数1: docker镜像名称
# 参数2: docker镜像的版本
# 0: 不存在
# 1: 存在
###################################################################
docker_check_is_image_version(){
    docker_image_name="$1"
    docker_image_version="$2"
    if docker image inspect "${docker_image_name}:${docker_image_version}" >/dev/null 2>&1; then
        log "✅ 镜像 ${docker_image_name}:${docker_image_version} 是存在的"
        return 1
    else
        log "❌ 镜像 ${docker_image_name}:${docker_image_version} 是不存在的"
        return 0
    fi
}

###################################################################
# 判定docker容器是否存在
# 参数1: docker容器名
# 0: 不存在
# 1: 存在
###################################################################
docker_check_is_container(){
    docker_container_name="$1"
    if docker container inspect "${docker_container_name}" >/dev/null 2>&1; then
        log "✅ 容器 ${docker_container_name} 存在（无论是否运行）"
        return 1
    else
        log "❌ 容器 ${docker_container_name} 不存在"
        return 0
    fi
}

###################################################################
# 判定docker容器是否运行
# 参数1: docker容器名
# 0: 没有运行
# 1: 运行
###################################################################
docker_check_running_container(){
    docker_container_name="$1"
    # 核心逻辑：读取容器State.Running字段，判断是否为true
    RUNNING=$(docker container inspect -f '{{.State.Running}}' "${docker_container_name}" 2>/dev/null)
    if [ "$RUNNING" = "true" ]; then
        log "✅ 容器 ${docker_container_name} 正在运行"
        return 1
    elif [ -n "$RUNNING" ]; then
        log "⚠️  容器 ${docker_container_name} 存在但未运行"
        return 0
    else
        log "❌ 容器 ${docker_container_name} 不存在"
        return 0
    fi
}

###################################################################
# 删除本地所有版本的镜像
# 参数1: 镜像名
###################################################################
docker_clean_image_all(){
    docker_image_name="$1"
    # 判定镜像是否存在
    docker_check_is_image "${docker_image_name}"
    if [ $? -ne 0 ]; then
        docker image rm $(docker image ls --format "{{.Repository}}:{{.Tag}}" "${docker_image_name}")
        if [ $? -ne 0 ]; then
            die "docker rm is error"
        fi
    fi
}

###################################################################
# 删除本地镜像
# 参数1: 镜像名
# 参数2: docker镜像的版本
###################################################################
docker_clean_image(){
    docker_image_name="$1"
    docker_image_version="$2"
    # 判定镜像是否存在
    docker_check_is_image_version "${docker_image_name}" "${docker_image_version}"
    if [ $? -ne 0 ]; then
        docker image rm "${docker_image_name}:${docker_image_version}"
        if [ $? -ne 0 ]; then
            die "docker rm is error"
        fi
    fi
}

###################################################################
# 删除本地容器
# 参数1: 容器名
###################################################################
docker_clean_container(){
    docker_container_name="$1"
    # 判定镜像是否存在
    docker_check_is_container "${docker_container_name}"
    if [ $? -ne 0 ]; then
        docker_check_running_container "${docker_container_name}"
        if [ $? -ne 0 ];then
            docker kill "${docker_container_name}" > /dev/null 2>&1
        fi
        docker container rm $(docker ps -a -f "name=${docker_container_name}" -q) > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "docker rm is error."
            exit 1
        fi
    fi
}

###################################################################
# 制作镜像
# 参数1: 镜像名
# 参数2: docker镜像的版本
# 参数3: 镜像配置文件路径
# 资源文件
###################################################################
docker_create_image(){
    docker_image_name="$1"
    docker_image_version="$2"
    docker_file_path="$3"
    # 删除容器
    docker_clean_container "${docker_image_name}"
    if [ $? -ne 0 ]; then
        die "docker_clean_container is error"
    fi
    # 判定镜像是否存在
    docker_clean_image_all "${docker_image_name}"
    if [ $? -ne 0 ]; then
        die "docker_clean_image is error"
    fi
    # 创建编译目录
    if [ ! -d "${build_dir}" ]; then
        mkdir ${build_dir}
    else
        rm ${build_dir}/* -rf
    fi

    # 拷贝编译资源进入编译路径
    cp ${resource_dir}/* ${build_dir}/ -rf
    #########################################
    # 制作镜像
    #########################################
    docker build -t "${docker_image_name}:${docker_image_version}" -f ${docker_file_path} ${build_dir}
    if [ $? -ne 0 ]; then
        die "docker build is error"
    fi
}

###################################################################
# 拉取腾讯镜像
# 参数1: 镜像名
# 参数2: docker镜像的版本
###################################################################
docker_tencent_pull_image(){
    docker_image_name="$1"
    docker_image_version="$2"
    # 先登录到私有仓库
    echo ${docker_tencent_registry_password} | docker login --username="${docker_tencent_registry_username}" --password-stdin  "${docker_tencent_registry_url}"
    if [ $? -ne 0 ]; then
        die "docker login is error"
    fi
    docker pull "${docker_tencent_registry_url}/${docker_tencent_registry_namespace}/${docker_tencent_registry_name}:${docker_image_version}"
    if [ $? -ne 0 ]; then
        die "docker pull is error"
    fi
    docker tag "${docker_tencent_registry_url}/${docker_tencent_registry_namespace}/${docker_tencent_registry_name}:${docker_image_version}" "${docker_image_name}:${docker_image_version}"
    if [ $? -ne 0 ]; then
        die "docker tag is error"
    fi
    docker image rm "${docker_tencent_registry_url}/${docker_tencent_registry_namespace}/${docker_tencent_registry_name}:${docker_image_version}"
    if [ $? -ne 0 ]; then
        die "docker image rm is error"
    fi
}

###################################################################
# 拉取github镜像
# 参数1: 镜像名
# 参数2: docker镜像的版本
###################################################################
docker_github_pull_image(){
    docker_image_name="$1"
    docker_image_version="$2"
    docker pull "${docker_github_registry_url}/${docker_github_registry_namespace}/${docker_github_registry_name}:${docker_image_version}"
    if [ $? -ne 0 ]; then
        die "docker pull is error"
    fi
    docker tag "${docker_github_registry_url}/${docker_github_registry_namespace}/${docker_github_registry_name}:${docker_image_version}" "${docker_image_name}:${docker_image_version}"
    if [ $? -ne 0 ]; then
        die "docker tag is error"
    fi
    docker image rm "${docker_github_registry_url}/${docker_github_registry_namespace}/${docker_github_registry_name}:${docker_image_version}"
    if [ $? -ne 0 ]; then
        die "docker image rm is error"
    fi
}

###################################################################
# 保存镜像
# 参数1: 镜像名
# 参数2: docker镜像的版本
###################################################################
docker_save_image(){
    docker_image_name="$1"
    docker_image_version="$2"
    # 创建保存目录
    if [ ! -d "${out_dir}" ]; then
        mkdir ${out_dir}
    else
        rm ${out_dir}/* -rf
    fi
    docker save "${docker_image_name}:${docker_image_version}" | gzip > ${out_dir}/${docker_image_name}_${docker_image_version}_docker.tar.gz
    if [ $? -ne 0 ]; then
        die "docker save is error"
    fi
}

###################################################################
# 获取输入参数
###################################################################
# 拉取标记 0: 不拉取 1: 拉取
let pull_flag=0
# 保存标记 0: 不保存 1: 保存
let save_flag=0
# 删除本地镜像 0: 不删除 1: 删除
let clean_flag=0

# 参数选项
arg_options="hcls"

# 获取参数输入
while getopts ${arg_options} opt
do
    case $opt in
        h)
            args_help
            exit 0
            ;;
        c)
            clean_flag=1
            ;;
        l)
            pull_flag=1
            ;;
        s)
            save_flag=1
            ;;
        ?)
            ;;
    esac
done
#通过shift $(($OPTIND - 1))的处理，$*中就只保留了除去选项内容的参数，
#可以在后面的shell程序中进行处理
shift $(($OPTIND - 1))

# 删除本地镜像下所有tag的操作
if [ ${clean_flag} -eq 1 ];then
    docker_clean_container "${docker_tencent_registry_name}"
    docker_clean_image_all "${docker_tencent_registry_name}"
    if [ $? -ne 0 ]; then
        die "docker_clean_image is error"
    fi
    if [ -d ${build_dir} ];then
        rm -rf ${build_dir}
    fi
    if [ -d ${out_dir} ];then
        rm -rf ${out_dir}
    fi
fi

###################################################################
# 获取用户名和密码
###################################################################
if [ ${pull_flag} -eq 1 ]; then
    # 选择docker类型
    log "=================选择拉取docker的类型========================"
    for((i=0;i<${#docker_pull_type_name_arry[*]};i++));  
    do
        docker_pull_type_tmp_doc=`echo ${docker_pull_type_name_arry[i]} |awk -F ':' '{print $2}'`
        docker_pull_type_nunber=$[${i}+1]
        log "${docker_pull_type_nunber}:  ${docker_pull_type_tmp_doc}"
    done
    read -p "请输入要编译的应用编号: " docker_pull_type_number_str
    
    docker_pull_type_nunber=$[${docker_pull_type_number_str}-1]
    # 默认目标
    docker_pull_type_name=`echo ${docker_pull_type_name_arry[${docker_pull_type_nunber}]} |awk -F ':' '{print $1}'`
    log "docker_type_name:$docker_pull_type_name"
    if [ ! -n "${docker_pull_type_name}" ]; then
        die "选择的序号${docker_pull_type_number_str}是没有定义的!"
    fi

    # 为腾讯云输入用户名和密码
    if [ "${docker_pull_type_name}" == 'tencent' ]; then
        # 输入docker用户名
        read -p "请输入腾讯用户名: " docker_tencent_registry_username
        if [ -z "$docker_tencent_registry_username" ]; then
            die "docker 用户名为空"
        fi

        # 输入docker密码
        read -s -p "请输入腾讯密码: " docker_tencent_registry_password
        if [ -z "$docker_tencent_registry_username" ]; then
            die "docker 密码为空"
        fi
    fi
fi

###################################################################
# 进行主操作
###################################################################
# 保存镜像的操作
if [ ${save_flag} -eq 1 ];then
    # 判定镜像是否存在
    docker_check_is_image_version "${docker_tencent_registry_name}" "${version}"
    if [ $? -eq 0 ]; then
        # 先进行镜像制作
        docker_create_image "${docker_tencent_registry_name}" "${version}" "${local_path}/Dockerfile"
        if [ $? -ne 0 ]; then
            die "docker_create_image is error"
        fi
    fi
    # 保存镜像
    docker_save_image "${docker_tencent_registry_name}" "${version}"
    if [ $? -ne 0 ]; then
        die "docker_save_image is error"
    fi
    # 最后在删除镜像
    docker_clean_image "${docker_tencent_registry_name}" "${version}"
    if [ $? -ne 0 ]; then
        die "docker_clean_image is error"
    fi
fi

if [ ${pull_flag} -eq 1 ];then
    # 拉取腾讯云
    if [ "${docker_pull_type_name}" == 'tencent' ]; then
        log "docker pull tencent"
        # 拉取镜像的操作
        docker_tencent_pull_image "${docker_tencent_registry_name}" "${version}"
        if [ $? -ne 0 ]; then
            die "docker pull tencent image is error"
        fi
    fi
    if [ "${docker_pull_type_name}" == 'github' ]; then
        log "docker pull github"
        docker_github_pull_image "${docker_tencent_registry_name}" "${version}"
        if [ $? -ne 0 ]; then
            die "docker pull github image is error"
        fi
    fi
fi

