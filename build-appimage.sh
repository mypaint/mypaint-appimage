#! /bin/bash

# Prefix (without the leading "/") in which RawTherapee and its dependencies are installed:
export PREFIX="$AIPREFIX"


# Set environment variables to allow finding the dependencies that are
# compiled from sources
#export PATH="/${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/lib64:/usr/local/lib:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:${PKG_CONFIG_PATH}"

locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"


# Add some required packages
(yum update -y && yum install -y epel-release) || exit 1
yum install -y https://centos7.iuscommunity.org/ius-release.rpm #|| exit 1
yum install -y centos-release-scl || exit 1
#yum install -y devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-7-libatomic-devel || exit 1
yum install -y intltool make git swig python-setuptools gettext gcc-c++ \
  python-devel numpy \
  gtk3-devel pygobject3-devel librsvg2-devel \
  libpng-devel lcms2-devel json-c-devel \
  gtk3 gobject-introspection || exit 1


mkdir -p /work || exit 1
cd /work || exit 1
if [ ! -e libmypaint ]; then
git clone https://github.com/mypaint/libmypaint.git || exit 1
cd libmypaint || exit 1
./autogen.sh --prefix=/usr/local || exit 1
./configure --prefix=/usr/local || exit 1
make install || exit 1
fi


mkdir -p /work || exit 1
cd /work || exit 1
if [ ! -e mypaint-brushes ]; then
git clone https://github.com/mypaint/mypaint-brushes.git
cd mypaint-brushes || exit 1
./autogen.sh --prefix=/usr/local || exit 1
./configure --prefix=/usr/local || exit 1
make install || exit 1
fi


cd /sources/mypaint || exit 1
python setup.py managed_install

touch /work/build.done

exit


(yum update -y && yum install -y libtool-ltdl-devel autoconf automake libtools which json-c-devel json-glib-devel gtk-doc gperf libuuid-devel libcroco-devel intltool libpng-devel cmake3 make git \
file bzip2 automake fftw-devel libjpeg-turbo-devel \
libwebp-devel libxml2-devel swig ImageMagick-c++-devel \
bc cfitsio-devel gsl-devel matio-devel \
giflib-devel pugixml-devel wget curl git itstool \
bison flex unzip dbus-devel libXtst-devel \
mesa-libGL-devel mesa-libEGL-devel vala \
libxslt-devel docbook-xsl libffi-devel \
libvorbis-devel python-six curl \
openssl-devel readline-devel expat-devel libtool \
pixman-devel libffi-devel gtkmm24-devel gtkmm30-devel libcanberra-devel \
lcms2-devel gtk-doc nano OpenEXR-devel libcroco-devel python36u python36u-libs python36u-devel python36u-pip gnome-common) || exit 1


source scl_source enable devtoolset-7

cd /usr/bin
ln -f -s python3.6 python3
ln -f -s python3.6-config python3-config
#exit 0


echo ""
echo "########################################################################"
echo ""
echo "Installing additional system packages"
echo ""

(cd /work && rm -rf libiptcdata* && wget https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/libiptcdata/1.0.4-6ubuntu1/libiptcdata_1.0.4.orig.tar.gz && tar xzvf libiptcdata_1.0.4.orig.tar.gz && cd libiptcdata-1.0.4 && ./configure --prefix=/usr/local && make -j 2 install) || exit 1


# Install missing six python module
cd /work || exit 1
rm -f get-pip.py
wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py
pip install six || exit 1
#python3 get-pip.py
#pip install six || exit 1
#exit




echo ""
echo "########################################################################"
echo ""
echo "Building and installing zenity"
echo ""

(cd /work && rm -rf zenity && git clone https://github.com/aferrero2707/zenity.git && \
cd zenity && ./autogen.sh && ./configure --prefix=/usr/local && make install) || exit 1

#exit


echo ""
echo "########################################################################"
echo ""
echo "Building and installing expat 2.2.5"
echo ""

(cd /work && rm -rf expat* && \
wget https://github.com/libexpat/libexpat/releases/download/R_2_2_5/expat-2.2.5.tar.bz2 && \
tar xvf expat-2.2.5.tar.bz2 && cd "expat-2.2.5" && \
./configure --prefix=/usr/local && make -j 2 install) || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Building and installing libtiff 4.0.9"
echo ""

(cd /work && rm -rf tiff* && \
wget http://download.osgeo.org/libtiff/tiff-4.0.9.tar.gz && \
tar xvf tiff-4.0.9.tar.gz && cd "tiff-4.0.9" && \
./configure --prefix=/usr/local && make -j 2 install) || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Building and installing librsvg"
echo ""

export PATH=$HOME/.cargo/bin:$PATH
(cd /work && curl https://sh.rustup.rs -sSf > ./r.sh && bash ./r.sh -y && \
rm -rf librsvg* && wget http://ftp.gnome.org/pub/gnome/sources/librsvg/2.40/librsvg-2.40.16.tar.xz && \
tar xvf librsvg-2.40.16.tar.xz && cd librsvg-2.40.16 && \
./configure --prefix=/usr/local && make -j 2 install) || exit 1


LFV=0.3.2
echo ""
echo "########################################################################"
echo ""
echo "Building and installing LensFun $LFV"
echo ""

# Lensfun build and install
(cd /work && rm -rf lensfun* && \
wget https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/lensfun/0.3.2-4/lensfun_0.3.2.orig.tar.gz && \
tar xzvf "lensfun_0.3.2.orig.tar.gz" && cd "lensfun-${LFV}" && \
patch -p1 < $AI_SCRIPTS_DIR/lensfun-glib-libdir.patch && \
mkdir -p build && cd build && 
cmake3 -DCMAKE_BUILD_TYPE="release" -DCMAKE_INSTALL_PREFIX="/usr/local" ../ && \
make --jobs=2 VERBOSE=1 install) || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Install Hicolor and Adwaita icon themes"

(cd /work && rm -rf hicolor-icon-theme-0.* && \
wget http://icon-theme.freedesktop.org/releases/hicolor-icon-theme-0.17.tar.xz && \
tar xJf hicolor-icon-theme-0.17.tar.xz && cd hicolor-icon-theme-0.17 && \
./configure --prefix=/usr/local && make install && rm -rf hicolor-icon-theme-0.*) || exit 1
echo "icons after hicolor installation:"
ls /${PREFIX}/share/icons
echo ""

(cd /work && rm -rf adwaita-icon-theme-3.* && \
wget http://ftp.gnome.org/pub/gnome/sources/adwaita-icon-theme/3.26/adwaita-icon-theme-3.26.0.tar.xz && \
tar xJf adwaita-icon-theme-3.26.0.tar.xz && cd adwaita-icon-theme-3.26.0 && \
./configure --prefix=/usr/local && make install && rm -rf adwaita-icon-theme-3.26.0*) || exit 1
echo "icons after adwaita installation:"
ls /${PREFIX}/share/icons
echo ""


echo ""
echo "########################################################################"
echo ""
echo "Building and installing RawTherapee"
echo ""

cd /sources
export GIT_DESCRIBE=$(git describe)
patch -N -p0 < /sources/ci/rt-lensfundbdir.patch #|| exit 1

# RawTherapee build and install
if [ x"${RT_BRANCH}" = "xreleases" ]; then
    CACHE_SUFFIX=""
else
    CACHE_SUFFIX="5-${RT_BRANCH}-ai"
fi
echo "RT cache suffix: \"${CACHE_SUFFIX}\""
mkdir -p /work/build/rt || exit 1
cd /work/build/rt || exit 1
rm -f /work/build/rt/CMakeCache.txt
cmake3 \
    -DCMAKE_BUILD_TYPE="release"  \
    -DCACHE_NAME_SUFFIX="${CACHE_SUFFIX}" \
    -DPROC_TARGET_NUMBER="0" \
    -DBUILD_BUNDLE="ON" \
    -DCMAKE_INSTALL_PREFIX="/usr/local/rt" \
    -DBUNDLE_BASE_INSTALL_DIR="/usr/local/rt/bin" \
    -DDATADIR=".." \
    -DLENSFUNDBDIR="share/lensfun/version_1" \
    -DOPTION_OMP="ON" \
    -DWITH_LTO="OFF" \
    -DWITH_PROF="OFF" \
    -DWITH_SAN="OFF" \
    -DWITH_SYSTEM_KLT="OFF" \
    /sources || exit 1
make --jobs=2 || exit 1
make install || exit 1

touch /work/build.done

