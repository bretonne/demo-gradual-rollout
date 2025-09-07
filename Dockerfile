FROM nginx:alpine
COPY index_v2.html /usr/share/nginx/html/index.html
COPY default.conf /etc/nginx/conf.d/default.conf
