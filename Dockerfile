FROM node:20-alpine

# Installing libvips-dev for sharp compatibility
RUN apk update && apk add --no-cache \
    build-base gcc autoconf automake zlib-dev \
    libpng-dev nasm bash vips-dev su-exec

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

# Limit memory during install/build to avoid OOM
ENV NODE_OPTIONS="--max-old-space-size=2048"

WORKDIR /opt/
COPY package.json package-lock.json ./
RUN npm config set fetch-retry-maxtimeout 600000 -g \
 && npm install --no-audit --no-fund
RUN npm install mysql2

WORKDIR /opt/app
COPY . .
ENV PATH=/opt/node_modules/.bin:$PATH
RUN chmod +x docker-entrypoint.sh \
 && chown -R node:node /opt/app
USER node

RUN npm run build

EXPOSE 1337

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["npm", "run", "start"]