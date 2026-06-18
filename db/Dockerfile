FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=inovatech123
ENV MYSQL_DATABASE=inovatech

COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 3306

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
  CMD mysqladmin ping -h localhost -u root -pinovatech123 || exit 1
