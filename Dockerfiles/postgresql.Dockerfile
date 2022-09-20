FROM postgres:14-alpine

# Copyright (c) 2022 Battelle Energy Alliance, LLC.  All rights reserved.
LABEL maintainer="malcolm@inl.gov"
LABEL org.opencontainers.image.authors='malcolm@inl.gov'
LABEL org.opencontainers.image.url='https://github.com/idaholab/Malcolm'
LABEL org.opencontainers.image.documentation='https://github.com/idaholab/Malcolm/blob/main/README.md'
LABEL org.opencontainers.image.source='https://github.com/idaholab/Malcolm'
LABEL org.opencontainers.image.vendor='Idaho National Laboratory'
LABEL org.opencontainers.image.title='malcolmnetsec/postgresql'
LABEL org.opencontainers.image.description='Malcolm container providing the PostgreSQL object-relational database'

ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ENV DEFAULT_UID $DEFAULT_UID
ENV DEFAULT_GID $DEFAULT_GID
ENV PUSER "postgres"
ENV PGROUP "postgres"
ENV PUSER_PRIV_DROP true
ENV PUSER_CHOWN "/run/postgresql;/var/lib/postgresql"

ENV TERM xterm

COPY --chmod=755 shared/bin/docker-uid-gid-setup.sh /usr/local/bin/

RUN set -x && \
   apk --no-cache add bash procps psmisc rsync shadow tini && \
   rsync -a /usr/local/bin/ /usr/bin/ && \
   rsync -a /usr/local/share/ /usr/share/ && \
   rsync -a /usr/local/lib/ /usr/lib/ && \
   rm -rf /usr/local/bin /usr/local/share /usr/local/lib && \
   ln -s /usr/bin /usr/local/bin && \
   ln -s /usr/share /usr/local/share && \
   ln -s /usr/lib /usr/local/lib

USER root

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/docker-uid-gid-setup.sh"]

CMD ["/usr/bin/docker-entrypoint.sh", "postgres"]

# to be populated at build-time:
ARG BUILD_DATE
ARG MALCOLM_VERSION
ARG VCS_REVISION

ENV BUILD_DATE $BUILD_DATE
ENV MALCOLM_VERSION $MALCOLM_VERSION
ENV VCS_REVISION $VCS_REVISION

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.version=$MALCOLM_VERSION
LABEL org.opencontainers.image.revision=$VCS_REVISION
