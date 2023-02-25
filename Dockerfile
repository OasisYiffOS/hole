FROM voremicrocomputers/yiffos-minimal-unstable:latest
WORKDIR /factory
RUN yes | bulge gi devel
RUN yes | bulge i isl # fixme: isl is needed for gcc, but not listed as a dependency of gcc
RUN yes | bulge i linux-headers # fixme: should be in devel group, but isnt. this will be fixed in the future
COPY sheath/sheath .
COPY hole_inner.sh .
RUN chmod +x hole_inner.sh