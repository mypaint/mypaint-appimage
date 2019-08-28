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
yum install -y intltool make git swig python-setuptools gettext gcc-c++ \
  python-devel numpy \
  gtk3-devel pygobject3-devel librsvg2-devel \
  libpng-devel lcms2-devel json-c-devel \
  gtk3 gobject-introspection || exit 1

# Optimize compiler flags for better perf
# These are pretty generic, ideally one would compile for own native arch
# We could try to target several CPU families in the future and distribute
# several binary packages.
export CFLAGS='-Ofast -ftree-vectorize -fopt-info-vec-optimized -funsafe-math-optimizations -funsafe-loop-optimizations'

cd /sources/libmypaint || exit 1
./autogen.sh --prefix=/usr/local || exit 1
./configure --prefix=/usr/local || exit 1
make install || exit 1


cd /sources/mypaint-brushes || exit 1
./autogen.sh --prefix=/usr/local || exit 1
./configure --prefix=/usr/local || exit 1
make install || exit 1


cd /sources/mypaint || exit 1
python setup.py managed_install

touch /work/build.done

exit

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
