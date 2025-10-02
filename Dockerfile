FROM tornadocookie/oasisyiffos-minimal:latest
#FROM voremicrocomputers/yiffos-bootstrap:latest
WORKDIR /factory
#RUN rm /var/run/dbus
RUN yes | bulge s
RUN yes | bulge u
# TODO glib2 is broken so we have this tmpfix
RUN yes | bulge gi devel || true
COPY sheath/sheath .
COPY hole_inner.sh .
RUN chmod +x hole_inner.sh