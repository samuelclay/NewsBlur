FROM node:14.4.0
ENV NODE_ENV=production
WORKDIR /node
# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY node/package*.json /node
ENV NODE_PATH=/node/node_modules/
RUN npm install
WORKDIR /srv
