# Sample Dockerfile for demonstration
# Replace this with your actual application Dockerfile

FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy application files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy app source
COPY . .

# Expose port
EXPOSE 8080

# Run the application
CMD [ "node", "server.js" ]
