FROM centos:7
LABEL maintainer="MyPaint Team"

RUN yum update -y && yum install -y epel-release
RUN yum install -y git wget file \
      intltool make git swig3 python-setuptools \
      gettext gcc-c++ python-devel numpy gtk3-devel \
      pygobject3-devel librsvg2-devel \
      libpng-devel lcms2-devel json-c-devel \
      gtk3 gobject-introspection
