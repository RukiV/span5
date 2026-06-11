# Build stage
FROM node:18-alpine AS build

WORKDIR /app

# Accept build arguments for environment variables
ARG REACT_APP_API_URL=http://localhost:8000
ARG REACT_APP_MICROSOFT_CLIENT_ID=your_client_id_here
ARG REACT_APP_MICROSOFT_TENANT_ID=your_tenant_id_here
ARG REACT_APP_REDIRECT_URI=http://localhost:3000/auth/callback

# Set environment variables from build args
ENV REACT_APP_API_URL=$REACT_APP_API_URL
ENV REACT_APP_MICROSOFT_CLIENT_ID=$REACT_APP_MICROSOFT_CLIENT_ID
ENV REACT_APP_MICROSOFT_TENANT_ID=$REACT_APP_MICROSOFT_TENANT_ID
ENV REACT_APP_REDIRECT_URI=$REACT_APP_REDIRECT_URI

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]