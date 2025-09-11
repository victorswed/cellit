# syntax=docker/dockerfile:1
FROM nginx:1.27-alpine
COPY apps/devhub/frontend/index.html /usr/share/nginx/html/index.html
COPY apps/devhub/frontend/about.html /usr/share/nginx/html/about.html
COPY apps/devhub/frontend/config.js /usr/share/nginx/html/config.js
COPY apps/devhub/frontend/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80