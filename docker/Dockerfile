FROM ubuntu:16.10
MAINTAINER krad.tv

WORKDIR /opt
RUN apt-get update -y
RUN apt-get install -y git build-essential nasm wget curl yasm g++ clang libicu-dev libpython2.7 libxml2 libxml2-dev libcurl3 
RUN wget https://swift.org/builds/swift-4.0.3-release/ubuntu1610/swift-4.0.3-RELEASE/swift-4.0.3-RELEASE-ubuntu16.10.tar.gz ; tar zxfv swift-4.0.3-RELEASE-ubuntu16.10.tar.gz
ENV PATH="/opt/swift-4.0.3-RELEASE-ubuntu16.10/usr/bin:${PATH}"
RUN wget http://ffmpeg.org/releases/ffmpeg-3.4.1.tar.gz ; tar zxfv ffmpeg-3.4.1.tar.gz
WORKDIR /opt/ffmpeg-3.4.1
RUN ./configure --prefix=/usr; make; make install
RUN git clone https://www.github.com/krad/pupil.git pupil
WORKDIR /opt/pupil
RUN git pull
RUN swift build
