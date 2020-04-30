FROM centos:7
LABEL maintainer="MyPaint Team"

RUN yum update -y && yum install -y epel-release
RUN yum install -y git wget file \
      intltool make git swig3 python-setuptools \
      gettext gcc-c++ python-devel numpy gtk3-devel \
      pygobject3-devel librsvg2-devel \
      libpng-devel lcms2-devel json-c-devel \
      gtk3 gobject-introspection
RUN yum install -y python2-pip
RUN pip install python-minifier
RUN bash -c '
for f in $(find / -name "*.py")
do
pyminify --remove-literal-statements --preserve-globals true "$f" > /tmp/tmpf.py && mv -f /tmp/tmpf.py "$f"
done
'

yum -y install centos-release-sc1
yum -y install devtoolset-7