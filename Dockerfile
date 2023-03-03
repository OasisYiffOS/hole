FROM voremicrocomputers/yiffos-minimal-unstable:latest
WORKDIR /factory
RUN yes | bulge s
RUN yes | bulge gi devel
COPY sheath/sheath .
COPY hole_inner.sh .
RUN chmod +x hole_inner.sh
