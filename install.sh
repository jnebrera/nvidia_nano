#!/usr/bin/env bash
# 2019 Michael de Gans

# Before executing this script, you need to increase SWAP size
# sudo vim /etc/systemd/nvzramconfig.sh

sudo nvpmodel -m 0
sudo jetson_clocks
sudo apt-get remove --purge libreoffice* -y
sudo apt-get remove --purge gnome* -y
sudo apt-get clean
sudo apt autoremove
sudo apt-get update
sudo apt-get upgrade
sudo apt dist-upgrade

# Install a bunch of libraries and needed applications

sudo apt-get install -y git cmake
sudo apt-get install -y libatlas-base-dev gfortran
sudo apt-get install -y libhdf5-serial-dev hdf5-tools
sudo apt-get install -y python3-dev locate
sudo apt-get install -y libfreetype6-dev python3-setuptools
sudo apt-get install -y protobuf-compiler libprotobuf-dev openssl
sudo apt-get install -y libssl-dev libcurl4-openssl-dev
sudo apt-get install -y cython3 libxml2-dev libxslt1-dev

# Install Python 3.9
# https://tech.serhatteker.com/post/2020-09/how-to-install-python39-on-ubuntu/

sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libreadline-dev libffi-dev wget
cd
mkdir workspace
cd workspace
wget https://www.python.org/ftp/python/3.9.0/Python-3.9.0.tgz
tar -xvzf Python-3.9.0.tgz
cd Python-3.9.0
./configure
sudo make altinstall

# Install latest cmake from source
cd
cd workspace
wget http://www.cmake.org/files/v3.20/cmake-3.20.2.tar.gz
tar xpvf cmake-3.20.2.tar.gz cmake-3.20.2/
cd cmake-3.20.2/
./bootstrap --system-curl
make -j4
echo 'export PATH=/home/nvidia/cmake-3.20.2/bin/:$PATH' >> ~/.bashrc
source ~/.bashrc

# Install FFMPEG with hardware encoding
# https://forums.developer.nvidia.com/t/hardware-decoding-in-mpv-player/75872/6

cd
cd workspace
wget http://Dragon.Studio/2021/02/ffmpeg-3.4.8-nvmpi-nvv4l2dec.zip
unzip -n ffmpeg-3.4.8-nvmpi-nvv4l2dec.zip
sudo apt -y --allow-change-held-packages --allow-downgrades install ./ffmpeg-*nvmpi-nvv4l2dec/*.deb
sudo apt-mark hold $(find ffmpeg-*nvmpi-nvv4l2dec | grep deb | xargs -n1 basename | cut -d_ -f1)

# Install Python packages

python3.9 -m pip install --upgrade pip
sudo apt-get install libgeos-dev
pip3.9 install shapely
pip3.9 install vidgear

# Install OpenCV from source
# Inspired by https://github.com/mdegans/nano_build_opencv/blob/master/build_opencv.sh
# 

wget https://raw.githubusercontent.com/jnebrera/nvidia_nano/main/build_opencv.sh
chmod 777 build_opencv.sh
./build_opencv.sh 4.5.2

# Test ffmpeg works
# wget https://file-examples-com.github.io/uploads/2017/04/file_example_MP4_1920_18MG.mp4
# ffmpeg -y -vsync 0 -c:v h264_nvmpi -i sample.mp4 -c:a copy -c:v h264_nvmpi -b:v 5M output.mp4

# Test OpenCV with CUDA works
# https://learnopencv.com/getting-started-opencv-cuda-module/