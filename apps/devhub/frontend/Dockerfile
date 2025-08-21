# syntax=docker/dockerfile:1
FROM nginx:1.27-alpine
COPY apps/devhub/frontend/index.html /usr/share/nginx/html/index.html
COPY apps/devhub/frontend/config.js /usr/share/nginx/html/config.js
EXPOSE 80
