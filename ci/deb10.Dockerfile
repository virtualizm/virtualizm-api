FROM debian:buster

ENV	DEBIAN_FRONTEND=noninteractive \
	LANG=C.UTF-8

RUN	apt-get update && \
	apt-get -y dist-upgrade && \
	apt-get -y --no-install-recommends install \
		curl \
		gnupg \
		ca-certificates \
		sudo

RUN	echo "ALL            ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers && \
	adduser --disabled-password --gecos "" build && \
	curl http://pkg.yeti-switch.org/key.gpg			| apt-key add - && \
	echo "deb http://pkg.yeti-switch.org/debian/buster unstable main"	>> /etc/apt/sources.list && \

RUN 	apt-get update && \
	apt-get -y --no-install-recommends install \
		libvirt0 \
		libvirt-dev \
		build-essential \
		devscripts \
		ca-certificates \
		debhelper \
		fakeroot \
		lintian \
		python-jinja2 \
		ruby2.6 \
		ruby2.6-dev \
		zlib1g-dev \
		python-yaml \
		git-changelog \
		python-setuptools \
		lsb-release \
		&& \
	apt-get clean && rm -rf /var/lib/apt/lists/*

