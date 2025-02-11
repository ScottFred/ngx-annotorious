# DO NOT EDIT -- Recommended to modify the original source of this Dockerfile
# Orignal Source:  https://gitlab.com/scottfred/angular-bootstrap

# Usage: Use GIT to pull Dockerfile into your newly created Angular Project
#    git archive --remote=git@gitlab.com:scottfred/angular-bootstrap HEAD | tar -x

# Rather than relying on Node.js:latest, be intentional
# Review versions of Angular are compatible with which versions of Node.js
# Angular and Node.js Versions: https://angular.io/guide/versions
# Node.js Docker Image tags: https://hub.docker.com/_/node/tags
FROM node:20.11.1-bullseye AS development

WORKDIR /app

# Based on Synk article, use dumb-init to start applications running in dev
RUN apt-get update && apt-get install -y --no-install-recommends dumb-init

# Try to install a newer version of npm-cli
RUN npm install -g npm@10.2.4

# Grab Node modules
COPY package*.json angular.json tsconfig*.json /app/

# Copy the projects directory first
COPY ./projects /app/projects/

# Install all necessary node packages based on package.json
RUN npm install 

# Build local packages in order
RUN npm run build @myrmidon/ngx-annotorious && \
   npm run build @myrmidon/cadmus-img-gallery && \
   npm run build @myrmidon/cadmus-img-gallery-iiif && \
   npm run build @myrmidon/ngx-annotorious-osd
# Build all libraries first using the defined script
# RUN npm run build-lib

# Copy the rest of the application
COPY ./src /app/src/

# Rather than relying on Angular:latest, be intentional
# Look online to find the latest Angular-CLI version
#  https://www.npmjs.com/package/@angular/cli
RUN npm install -g @angular/cli@19.0.5

USER node

# Use `dumb-init` to allow SIGKILL
CMD dumb-init ng serve --host 0.0.0.0

# ---- Angular build/package for production ------
FROM node:20.11.1-bullseye AS builder

WORKDIR /app

RUN npm install -g npm@10.2.4
# TODO: set the Angular version once above and use that
# TODO: allow a Docker command line argument ARG to be
#       "passed in" to set this
RUN npm install -g @angular/cli@19.0.5

# Copy configuration files (to include Angular config) first
COPY package*.json angular.json tsconfig*.json /app/

# Copy the projects directory first
COPY ./projects /app/projects/

# Install dependencies
RUN npm install

# Build local packages in order
RUN npm run build @myrmidon/ngx-annotorious && \
   npm run build @myrmidon/cadmus-img-gallery && \
   npm run build @myrmidon/cadmus-img-gallery-iiif && \
   npm run build @myrmidon/ngx-annotorious-osd
# Build all libraries first using the defined script
# RUN npm run build-lib

# Minify Angular App for production deployment
COPY ./src /app/src/
RUN ng build --configuration production

# Add this line to see the contents
# RUN echo "Checking dist directory structure:" && \
#    ls -la /app/dist && \
#    echo "\nChecking for ngx-annotorious directory:" && \
#    ls -la /app/dist/ngx-annotorious || true && \
#    echo "\nChecking complete dist directory tree:" && \
#    find /app/dist -type f

# ---- Docker Nginx Production image to serve Angular app ------
# TODO: consider moving Nginx to smaller Alpine image
FROM nginx:1.25.1 AS production

WORKDIR /app

# If we need a more complex Nginx configuration
# COPY ./nginx.conf /etc/nginx/sites-enabled/

RUN rm -rf /usr/share/nginx/html/*

# See https://hub.docker.com/_/nginx more more information
#  about using Nginx Docker Container
COPY --from=builder /app/dist/ngx-annotorious/* /usr/share/nginx/html/

RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

# How to build:
# docker build --target production -t housing:production

# Run from command line with: 
# docker run --rm  -p 8080:80 housing:production nginx -g 'daemon off;'
# URL: localhost:8080

# https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-docker/
# OR
# with the CMD line below, run as:
# docker run --rm -p 8080:80 housing:production
# URL: localhost:8080

STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
