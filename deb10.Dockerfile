ARG DEBIAN=deb10
FROM virtualizm/virtualizm-api:${DEBIAN}-build
USER build
ADD --chown=build:build Gemfile Gemfile.lock Makefile vendor /build/virtualizm-api
WORKDIR /build/virtualizm-api
RUN make gems-test
ADD --chown=build:build . /build/virtualizm-api/
