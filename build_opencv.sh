#!/usr/bin/env bash
# 2019 Michael de Gans

set -e

# change default constants here:
readonly PREFIX=/usr/local  # install prefix, (can be ~/.local for a user install)
readonly DEFAULT_VERSION=4.5.2  # controls the default version (gets reset by the first argument)
readonly CPUS=$(nproc)  # controls the number of jobs

# better board detection. if it has 6 or more cpus, it probably has a ton of ram too
if [[ $CPUS -gt 5 ]]; then
    # something with a ton of ram
    JOBS=$CPUS
else
    JOBS=2  # you can set this to 4 if you have a swap file
    # otherwise a Nano will choke towards the end of the build
fi

cleanup () {
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script

    rm -rf /tmp/build_opencv

#    while true ; do
#        echo "Do you wish to remove temporary build files in /tmp/build_opencv ? "
#        if ! [[ "$1" -eq "--test-warning" ]] ; then
#            echo "(Doing so may make running tests on the build later impossible)"
#        fi
#        read -p "Y/N " yn
#        case ${yn} in
#            [Yy]* ) rm -rf /tmp/build_opencv ; break;;
#            [Nn]* ) exit ;;
#            * ) echo "Please answer yes or no." ;;
#        esac
#    done
}

setup () {
    cd /tmp
    if [[ -d "build_opencv" ]] ; then
        echo "It appears an existing build exists in /tmp/build_opencv"
        cleanup
    fi
    mkdir build_opencv
    cd build_opencv
}

git_source () {
    echo "Getting version '$1' of OpenCV"
    git clone --depth 1 --branch "$1" https://github.com/opencv/opencv.git
    git clone --depth 1 --branch "$1" https://github.com/opencv/opencv_contrib.git
}

install_dependencies () {
    # open-cv has a lot of dependencies, but most can be found in the default
    # package repository or should already be installed (eg. CUDA).
    # I have removed some packages from here as they are blocked by hardware accelerated ffmpeg
    echo "Installing build dependencies."
    sudo apt-get update
    sudo apt-get dist-upgrade -y --autoremove
    sudo apt-get install -y \
        build-essential \
        git \
        gfortran \
        libatlas-base-dev \
        libblas-dev \
        libcanberra-gtk3-module \
        libdc1394-22-dev \
        libeigen3-dev \
        libfaac-dev \
        libgflags-dev \
        libglew-dev \
        libgoogle-glog-dev \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer-plugins-good1.0-dev \
        libgstreamer1.0-dev \
        libgtk-3-dev \
        libgtk2.0-dev \
        libcanberra-gtk* \
        libjpeg-dev \
        libjpeg8-dev \
        libjpeg-turbo8-dev \
        liblapack-dev \
        liblapacke-dev \
        libmp3lame-dev \
        libopenblas-dev \
        libopencore-amrnb-dev \
        libopencore-amrwb-dev \
        libpng-dev \
        libpostproc-dev \
        libtbb-dev \
        libtbb2 \
        libtesseract-dev \
        libtheora-dev \
        libtiff-dev \
        libv4l-dev \
        libvorbis-dev \
        libxine2-dev \
        libxvidcore-dev \
        libx264-dev \
        pkg-config \
        qv4l2 \
        v4l-utils \
        v4l2ucp \
        zlib1g-dev
}

configure () {
    local CMAKEFLAGS="
        -D BUILD_EXAMPLES=OFF
        -D BUILD_opencv_python2=OFF
        -D BUILD_opencv_python3=ON
        -D PYTHON3_EXECUTABLE=/usr/local/bin/python3.9
        -D PYTHON3_INCLUDE_DIR=/usr/local/include/python3.9/
        -D PYTHON3_LIBRARY=/usr/local/lib/libpython3.9.a
        -D PYTHON3_PACKAGES_PATH=/usr/local/lib/python3.9/site-packages/
        -D PYTHON3_NUMPY_INCLUDE_DIRS=~/.local/lib/python3.9/site-packages/numpy/core/include
        -D CMAKE_BUILD_TYPE=RELEASE
        -D CMAKE_INSTALL_PREFIX=${PREFIX}
        -D CUDA_ARCH_BIN=5.3,6.2,7.2
        -D CUDA_ARCH_PTX=
        -D CUDA_FAST_MATH=ON
        -D CUDNN_VERSION='8.0'
        -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 
        -D ENABLE_NEON=ON
        -D OPENCV_DNN_CUDA=ON
        -D OPENCV_ENABLE_NONFREE=ON
        -D OPENCV_EXTRA_MODULES_PATH=/tmp/build_opencv/opencv_contrib/modules
        -D OPENCV_GENERATE_PKGCONFIG=ON
        -D WITH_CUBLAS=ON
        -D WITH_CUDA=ON
        -D WITH_CUDNN=ON
        -D WITH_GSTREAMER=ON
        -D WITH_4VL=ON
        -D WITH_LIBV4L=ON
        -D WITH_QT=OFF
        -D BUILD_TIFF=ON
        -D WITH_FFMPEG=ON
        -D WITH_GSTREAMER=ON
        -D ENABLE_FAST_MATH=ON
        -D WITH_OPENCL=OFF
        -D WITH_CUBLAS=ON
        -D WITH_OPENMP=ON
        -D WITH_TBB=ON
        -D BUILD_TBB=ON
        -D BUILD_TESTS=OFF
        -D WITH_EIGEN=ON
        -D WITH_OPENGL=ON"

    if [[ "$1" != "test" ]] ; then
        CMAKEFLAGS="
        ${CMAKEFLAGS}
        -D BUILD_PERF_TESTS=OFF
        -D BUILD_TESTS=OFF"
    fi

    echo "cmake flags: ${CMAKEFLAGS}"

    cd opencv
    mkdir build
    cd build
    cmake ${CMAKEFLAGS} .. 2>&1 | tee -a configure.log
}

main () {

    local VER=${DEFAULT_VERSION}

    # parse arguments
    if [[ "$#" -gt 0 ]] ; then
        VER="$1"  # override the version
    fi

    if [[ "$#" -gt 1 ]] && [[ "$2" == "test" ]] ; then
        DO_TEST=1
    fi

    # prepare for the build:
    setup
    install_dependencies
    git_source ${VER}

    if [[ ${DO_TEST} ]] ; then
        configure test
    else
        configure
    fi

    # start the build
    make -j${JOBS} 2>&1 | tee -a build.log

    if [[ ${DO_TEST} ]] ; then
        make test 2>&1 | tee -a test.log
    fi

    # avoid a sudo make install (and root owned files in ~) if $PREFIX is writable
    if [[ -w ${PREFIX} ]] ; then
        make install 2>&1 | tee -a install.log
    else
        sudo make install 2>&1 | tee -a install.log
    fi

    cleanup --test-warning

}

main "$@"
