# Use Alpine for minimal size
FROM node:18-alpine

# Set working directory inside container
WORKDIR /app

# Copy package files first
# We do this separately so Docker caches dependencies
# If only app.js changes — npm install won't run again
COPY package*.json ./

# Install dependencies
RUN npm install

# Now copy app code
COPY . .

# Expose port
EXPOSE 3000

# Start the app
CMD ["node", "app.js"]
