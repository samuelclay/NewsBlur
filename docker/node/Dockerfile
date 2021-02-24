FROM node:14.4.0
WORKDIR /srv/newsblur/node
ENV NODE_ENV=production

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY node/package*.json ./

RUN npm install

COPY node/*.js ./
