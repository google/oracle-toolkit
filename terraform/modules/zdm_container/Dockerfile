FROM oraclelinux:8

# Install ZDM prerequisites
RUN dnf install -y \
    unzip \
    expect \
    glibc-devel \
    libaio \
    libnsl \
    ncurses-compat-libs \
    perl-interpreter \
    openssh-clients \
    sudo \
    hostname \
    procps \
    && dnf clean all

# Create zdm user and group
RUN groupadd zdm && useradd -g zdm -m -s /bin/bash zdmuser

# Set ZDM environment variables
ENV ZDM_BASE=/u01/zdm/zdmbase
ENV ZDM_HOME=/u01/zdm/zdmhome
ENV PATH=$PATH:$ZDM_HOME/bin
ENV SKIP_RESOURCE_CHECK=true

# Prepare directory structures
RUN mkdir -p /u01/zdm/zdmhome /u01/zdm/zdmbase /u01/zdm/zdminstall

# Expecting zdminstall.zip in the build context.
# You can use the helper script 'build.sh' to download it directly from GCS and build:
#   ./build.sh -b my-software-bucket -z V1035502-01.zip -t gcr.io/my-project/zdm-service:latest
COPY zdminstall.zip /u01/zdm/

RUN chown -R zdmuser:zdm /u01/zdm

USER zdmuser

# Unpack and run ZDM installation
RUN unzip -q /u01/zdm/zdminstall.zip -d /u01/zdm/zdminstall/ \
    && cd /u01/zdm/zdminstall/* \
    && sed -i 's|runInstaller -silent|runInstaller -silent -ignorePrereqs -ignoreSysPrereqs|g' zdminstall.sh \
    && (./zdminstall.sh setup oraclehome=$ZDM_HOME oraclebase=$ZDM_BASE ziploc=$(pwd)/zdm_home.zip || (cat /u01/zdm/zdmbase/crsdata/*/rhp/logs/*.out /u01/zdm/zdmhome/inventory/logs/*.log 2>/dev/null; exit 1)) \
    && rm -rf /u01/zdm/zdminstall.zip /u01/zdm/zdminstall \
    && cp -r /u01/zdm/zdmbase /u01/zdm/zdmbase_template

WORKDIR /home/zdmuser

# Copy entrypoint script
COPY --chown=zdmuser:zdm entrypoint.sh /u01/zdm/entrypoint.sh
RUN chmod +x /u01/zdm/entrypoint.sh

EXPOSE 8900 8897 8898

ENTRYPOINT ["/u01/zdm/entrypoint.sh"]
