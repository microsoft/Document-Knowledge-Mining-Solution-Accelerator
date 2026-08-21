# Use the official Node.js image from the Docker Hub
FROM node:20

# Set the working directory inside the container
WORKDIR /app

# Copy package.json, yarn.lock and .npmrc (registry config) to the working directory
COPY package.json yarn.lock .npmrc ./

# Install dependencies
RUN yarn install

# Copy the rest of the application code to the working directory
COPY . .

# Expose the port the app runs on
EXPOSE 5900

# Specify the command to run the application
CMD ["yarn", "start"]