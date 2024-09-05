# 使用官方的 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04 AS builder

# 设置工作目录
WORKDIR /app

# 更新包列表并安装必要的工具和依赖
RUN apt-get update && \
    apt-get install -y \
        curl \
        git \
        build-essential \
        libgtk-3-dev \
        libwebkit2gtk-4.0-dev \
        unzip \
        wget \
        upx \
        python3 \
        python3-pip \
        bash \
        ca-certificates # 安装 ca-certificates 包

# 更新系统中的 CA 证书
RUN update-ca-certificates

# 安装 Node.js 14.x 并安装兼容的 npm 版本
RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs

# 配置 npm 使用 npmmirror 镜像源
RUN npm config set registry https://registry.npmmirror.com
RUN npm config set disturl https://npmmirror.com/dist
RUN npm config set @scope:registry https://registry.npmmirror.com

# 安装兼容的 npm 版本
RUN npm install -g npm@6

# 安装 Go
RUN wget https://dl.google.com/go/go1.20.5.linux-amd64.tar.gz
RUN cp go1.20.5.linux-amd64.tar.gz /tmp/go.tar.gz
RUN tar -C /usr/local -xzf /tmp/go.tar.gz
RUN rm /tmp/go.tar.gz

# 设置 Go 环境变量
ENV PATH="$PATH:/usr/local/go/bin"

# 下载并安装 Wails
COPY download_wails.sh /tmp/download_wails.sh
RUN chmod +x /tmp/download_wails.sh
RUN /tmp/download_wails.sh

# 安装 Python 依赖
COPY ./thirdparty/requirements.txt /app/thirdparty/requirements.txt
RUN pip3 install -r thirdparty/requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 安装前端依赖
COPY ./frontend/package.json ./frontend/package-lock.json /app/frontend/
RUN cd frontend && npm install

# 编译应用
COPY . /app
RUN go mod tidy
RUN go install github.com/wailsapp/wails/v2/cmd/wails@latest
RUN cd thirdparty && pyinstaller -F -w pdf.py
RUN cp dist/pdf /app/build/bin/
RUN cp ocr.py convert_external.py /app/build/bin/
RUN wails build -upx -ldflags "-s -w"

# 创建最终镜像
FROM ubuntu:22.04

# 复制编译好的二进制文件到最终镜像
COPY --from=builder /app/build/bin/ /app/

# 设置环境变量
ENV NAME GuruService \
    VERSION 1.0.12

# 暴露端口
EXPOSE 8080

# 定义启动命令
CMD ["./pdf-guru"]
