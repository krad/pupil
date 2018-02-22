FROM ubuntu:artful
MAINTAINER krad.tv

WORKDIR /opt
RUN apt-get autoclean; apt-get clean
RUN apt-get update -y
RUN apt-get install -y git build-essential nasm wget curl yasm g++ clang libicu-dev libpython2.7 libxml2 libxml2-dev libcurl3
RUN wget https://swift.org/builds/swift-4.0.3-release/ubuntu1610/swift-4.0.3-RELEASE/swift-4.0.3-RELEASE-ubuntu16.10.tar.gz ; tar zxfv swift-4.0.3-RELEASE-ubuntu16.10.tar.gz
ENV PATH="/opt/swift-4.0.3-RELEASE-ubuntu16.10/usr/bin:${PATH}"
RUN apt-get install -y libavcodec-dev libavcodec57 libavformat-dev libavformat57 libavresample-dev libavresample3 libavutil-dev libavutil55 libswresample-dev libswresample2 libswscale-dev libswscale4
#RUN wget http://ffmpeg.org/releases/ffmpeg-3.4.1.tar.gz ; tar zxfv ffmpeg-3.4.1.tar.gz
#WORKDIR /opt/ffmpeg-3.4.1
#RUN ./configure --prefix=/usr; make; make install
WORKDIR /opt
RUN mkdir broadcasts
RUN git clone https://github.com/krad/pupil.git pupil
WORKDIR /opt/pupil
RUN git fetch --all --tags --prune
RUN swift build --build-path ./build -c release

EXPOSE 42000

CMD ["/opt/pupil/build/release/pupil"]
