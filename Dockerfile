# Dockerfile

# Use an official Ruby runtime as a parent image
FROM ruby:3.2.2

# Install essential dependencies
# - build-essential: for compiling gems
# - libpq-dev: for the 'pg' gem to connect to PostgreSQL
# - nodejs & yarn: for the asset pipeline / javascript management
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs yarn

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy the main application code into the container
COPY . .

# Expose port 3000 to allow incoming connections to the Rails server
EXPOSE 3000

# The main command to run when the container starts.
# We bind to 0.0.0.0 to allow connections from outside the container.
CMD ["rails", "server", "-b", "0.0.0.0"]
