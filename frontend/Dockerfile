FROM node:24.12.0-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_API_MODE=live
ARG VITE_LOCAL_AUTH=true
ENV VITE_API_MODE=$VITE_API_MODE VITE_LOCAL_AUTH=$VITE_LOCAL_AUTH
RUN npm run build
FROM nginxinc/nginx-unprivileged:1.28.0-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
USER 101
EXPOSE 8080
