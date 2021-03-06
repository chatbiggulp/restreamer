FROM node:4.2.3-slim

MAINTAINER datarhei <info@datarhei.org>

ENV FFMPEG_VERSION 2.8.1
ENV YASM_VERSION 1.3.0
ENV LAME_VERSION 3.99.5
ENV NGINX_VERSION 1.8.0

ENV SRC /usr/local
ENV LD_LIBRARY_PATH ${SRC}/lib
ENV PKG_CONFIG_PATH ${SRC}/lib/pkgconfig

ENV BUILDDEPS "autoconf automake gcc g++ libtool make nasm zlib1g-dev libssl-dev xz-utils cmake perl build-essential libpcre3-dev unzip"

RUN rm -rf /var/lib/apt/lists/* && \
    apt-get update && \
    apt-get install -y curl wget git libpcre3 tar ${BUILDDEPS}

# yasm
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -Os http://www.tortall.net/projects/yasm/releases/yasm-${YASM_VERSION}.tar.gz && \
    tar xzvf yasm-${YASM_VERSION}.tar.gz && \
    cd yasm-${YASM_VERSION} && \
    ./configure --prefix="$SRC" --bindir="${SRC}/bin" && \
    make && \
    make install && \
    make distclean && \
    rm -rf ${DIR}

# x264
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    git clone --depth 1 git://git.videolan.org/x264 && \
    cd x264 && \
    ./configure --prefix="$SRC" --bindir="${SRC}/bin" --enable-static && \
    make && \
    make install && \
    make distclean && \
    rm -rf ${DIR}

# libmp3lame
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -L -Os http://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION%.*}/lame-${LAME_VERSION}.tar.gz  && \
    tar xzvf lame-${LAME_VERSION}.tar.gz  && \
    cd lame-${LAME_VERSION} && \
    ./configure --prefix="${SRC}" --bindir="${SRC}/bin" --disable-shared --enable-nasm && \
    make && \
    make install && \
    make distclean&& \
    rm -rf ${DIR}

# ffmpeg
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -Os http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz && \
    tar xzvf ffmpeg-${FFMPEG_VERSION}.tar.gz && \
    cd ffmpeg-${FFMPEG_VERSION} && \
    ./configure --prefix="${SRC}" --extra-cflags="-I${SRC}/include" --extra-ldflags="-L${SRC}/lib" --bindir="${SRC}/bin" \
    --extra-libs=-ldl --enable-version3 --enable-libmp3lame --enable-libx264 --enable-gpl \
    --enable-postproc --enable-nonfree --enable-avresample --disable-debug --enable-small --enable-openssl && \
    make && \
    make install && \
    make distclean && \
    hash -r && \
    cd tools && \
    make qt-faststart && \
    cp qt-faststart ${SRC}/bin && \
    rm -rf ${DIR}
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/libc.conf
RUN ffmpeg -buildconf

# nginx-rtmp
RUN DIR=$(mktemp -d) && cd ${DIR} && \
    curl -LOks http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
      tar -zxvf nginx-${NGINX_VERSION}.tar.gz && \
    curl -LOks https://github.com/arut/nginx-rtmp-module/archive/master.zip && \
      unzip master.zip && \
      rm master.zip && \
    cd nginx-${NGINX_VERSION} && \
    ./configure --with-http_ssl_module --add-module=../nginx-rtmp-module-master && \
    make && \
    make install && \
    rm -rf ${DIR}

RUN apt-get purge -y --auto-remove ${BUILDDEPS} && \
    apt-get install -y git && \
    rm -rf /tmp/*

COPY . /restreamer
WORKDIR /restreamer

RUN npm install -g bower grunt-bower grunt-cli public-ip && \
    npm install && \
    grunt build

ENV RESTREAMER_USERNAME admin
ENV RESTREAMER_PASSWORD datarhei

EXPOSE 8080
VOLUME ["/restreamer/db"]

CMD ["./run.sh"]
