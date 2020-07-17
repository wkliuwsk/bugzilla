FROM ubuntu:20.04
MAINTAINER liu weikang <wkliuwsk@163.com>

# Environment configuration
ENV BUGS_DB_DRIVER mysql
ENV BUGS_DB_NAME bugs
ENV BUGS_DB_PASS bugs
ENV BUGS_DB_HOST localhost

ENV BUGZILLA_USER bugzilla
ENV BUGZILLA_HOME /home/$BUGZILLA_USER
ENV BUGZILLA_ROOT $BUGZILLA_HOME/devel/htdocs/bugzilla
ENV BUGZILLA_URL http://localhost/bugzilla

ENV GITHUB_BASE_GIT https://github.com/bugzilla/bugzilla
ENV GITHUB_BASE_BRANCH 5.2
ENV GITHUB_QA_GIT https://github.com/bugzilla/qa

ENV ADMIN_EMAIL admin@bugzilla.org
ENV ADMIN_PASS password

# change sources
RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak \
    && sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list \
    && apt update && apt upgrade -y -q

# Config tzdata
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get install -y --fix-missing tzdata \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata

# Distribution package installation
ADD  ./packageList/*  /
RUN apt -y -q --fix-missing install `cat /bases.list`
RUN apt -y -q --fix-missing install `cat /command.list`
RUN apt -y -q --fix-missing install `cat /libs.list` 

RUN apt -y -q --fix-missing install `cat /service.list`
RUN apt -y -q --fix-missing install `cat /tools.list`
RUN apt -y -q install `cat /others.list`

RUN apt autoclean && apt autoremove && rm -rf /*.list

# User configuration
RUN useradd -m -G sudo -u 1000 -s /bin/bash $BUGZILLA_USER \
    && usermod -p PASSWORD $BUGZILLA_USER && passwd -u $BUGZILLA_USER \
    && echo "bugzilla:bugzilla" | chpasswd

# Apache configuration
COPY ./configure/bugzilla.conf /etc/httpd/conf.d/bugzilla.conf

# MySQL configuration
COPY ./configure/my.cnf /etc/my.cnf
RUN chmod 644 /etc/my.cnf \
    && chown root.root /etc/my.cnf 
# RUN rm -rf /etc/mysql \
#     && rm -rf /var/lib/mysql/*

# RUN mysqld --initialize  --user=$BUGZILLA_USER --datadir=/var/lib/mysql
# RUN /usr/bin/mysql_install_db --user=$BUGZILLA_USER --basedir=/usr --datadir=/var/lib/mysql

# Sudoer configuration
COPY ./others/sudoers /etc/sudoers
RUN chown root.root /etc/sudoers && chmod 440 /etc/sudoers

# Clone the code repo
RUN su $BUGZILLA_USER -c "git clone $GITHUB_BASE_GIT -b $GITHUB_BASE_BRANCH $BUGZILLA_ROOT"

# Copy setup and test scripts
COPY ./script/*.sh ./script/buildbot_step /others/checksetup_answers.txt /
RUN chmod 755 /*.sh /buildbot_step

# Bugzilla dependencies and setup
RUN /install_deps.sh
RUN /bugzilla_config.sh
RUN /my_config.sh

# Final permissions fix
RUN chown -R $BUGZILLA_USER.$BUGZILLA_USER $BUGZILLA_HOME

# Networking
# RUN echo "NETWORKING=yes" > /etc/sysconfig/network
EXPOSE 22 80 5900

# Testing scripts for CI
# ADD https://selenium-release.storage.googleapis.com/2.45/selenium-server-standalone-2.45.0.jar /selenium-server.jar
COPY ./others/selenium-server-standalone-2.45.0.jar selenium-server.jar

# Supervisor
COPY ./configure/supervisord.conf /etc/supervisord.conf
RUN chmod 700 /etc/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
