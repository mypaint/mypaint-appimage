#! /bin/bash

#rm -rf RawTherapee
if [ ! -e mypaint ]; then
	git clone https://github.com/mypaint/mypaint.git
fi
#docker run -it -v $(pwd):/sources -e "RT_BRANCH=$RT_BRANCH" photoflow/docker-centos7-gtk bash
docker run -it -v $(pwd):/sources centos:7 bash #/sources/ci/appimage-centos7.sh

