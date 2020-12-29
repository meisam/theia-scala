ARG NODE_VERSION=12.18.3
FROM node:${NODE_VERSION}-alpine
RUN apk add --no-cache make pkgconfig gcc g++ python libx11-dev libxkbfile-dev
ARG version=latest
WORKDIR /home/theia
ADD $version.package.json ./package.json
ARG GITHUB_TOKEN
RUN yarn --pure-lockfile && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn theia build && \
    yarn theia download:plugins && \
    yarn --production && \
    yarn autoclean --init && \
    echo *.ts >> .yarnclean && \
    echo *.ts.map >> .yarnclean && \
    echo *.spec.* >> .yarnclean && \
    yarn autoclean --force && \
    yarn cache clean

FROM node:${NODE_VERSION}-alpine
# See : https://github.com/theia-ide/theia-apps/issues/34
RUN addgroup theia && \
    adduser -G theia -s /bin/sh -D theia;
RUN chmod g+rw /home && \
    mkdir -p /home/project && \
    chown -R theia:theia /home/theia && \
    chown -R theia:theia /home/project;
RUN apk add --no-cache git openssh bash
ENV HOME /home/theia
WORKDIR /home/theia
COPY --from=0 --chown=theia:theia /home/theia /home/theia
EXPOSE 3000
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/theia/plugins \
    JAVA_HOME=/usr/lib/jvm/default-jvm/jre
ENV USE_LOCAL_GIT true
RUN apk add  --no-cache --virtual=.build-dependencies openjdk11
RUN cd /tmp && \
    wget https://github.com/sbt/sbt/releases/download/v1.4.5/sbt-1.4.5.tgz && \
    tar -C /usr/local -xzf sbt-1.4.5.tgz && \
    rm -rf /tmp/sbt-1.4.5.tgz && \
    ln -s /usr/local/sbt/bin/sbt /usr/local/bin/sbt && \

    wget https://github.com/lampepfl/dotty/releases/download/3.0.0-M3/scala3-3.0.0-M3.tar.gz && \
    tar -C /usr/local/ -xzf scala3-3.0.0-M3.tar.gz && \
    ln -s /usr/local/scala3-3.0.0-M3 /usr/local/scala3 && \
    ln -s /usr/local/scala3 /usr/local/scala && \
    for f in /usr/local/scala3-3.0.0-M3/bin/*; do ln -s "$f" "/usr/local/bin/$(basename "$f")"; done
COPY sbtopts /usr/local/sbt/conf/sbtopts
USER theia
ENTRYPOINT [ "node", "/home/theia/src-gen/backend/main.js", "/home/project", "--hostname=0.0.0.0" ]
