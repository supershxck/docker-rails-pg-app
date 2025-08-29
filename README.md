# docker-rails-pg-app


Excellent question. Moving this entire workflow into Docker is a standard, powerful practice in modern web development. It provides a consistent, reproducible, and isolated environment for your entire application stack, from development to production.

This approach encapsulates the "truth" of your application's required environment into code, which is a creatively inspiring way to ensure it works the same way everywhere, for everyone on your team.

Here is a complete, step-by-step guide to dockerizing your Rails and PostgreSQL application.

### Prerequisites

1.  **Docker Desktop Installed**: Make sure you have Docker and Docker Compose installed and running on your system. You can get it from the [official Docker website](https://www.docker.com/products/docker-desktop/).

### Step 1: Generate the Rails App (with a Docker-friendly DB config)

First, we'll generate the new Rails app. We'll tell Rails to pre-configure the `database.yml` file to use a hostname (`db`) that we'll define in our Docker setup.

```bash
# We don't need to run this inside a container yet
rails new todo_web --database=postgresql
cd todo_web
```

*Note: We're not using the `-d` flag here. Instead, we'll configure the `database.yml` file manually in a later step to make it read from environment variables, which is a Docker best practice.*

### Step 2: Create the `Dockerfile`

In the root of your `todo_web` directory, create a file named `Dockerfile` (no extension). This file is the recipe for building your Rails application's image.

```dockerfile
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
```

### Step 3: Create the `docker-compose.yml` File

This file orchestrates your services (the Rails app and the PostgreSQL database), defining how they run and connect to each other. In your project root, create a file named `docker-compose.yml`.

```yaml
# docker-compose.yml

version: '3.8'

services:
  # The PostgreSQL Database Service
  db:
    image: postgres:15 # Use official postgres image
    volumes:
      - postgres_data:/var/lib/postgresql/data # Persist data
    environment:
      POSTGRES_PASSWORD: password # Set a password
      # Rails will create the DB, so we don't need POSTGRES_DB

  # The Rails Application Service
  web:
    build: . # Build the image from the Dockerfile in the current directory
    command: bash -c "rm -f tmp/pids/server.pid && bundle exec rails s -p 3000 -b '0.0.0.0'"
    volumes:
      - .:/usr/src/app # Mount your app code into the container for live updates
    ports:
      - "3000:3000"
    depends_on:
      - db # Wait for the db service to start before starting the web service
    environment:
      DATABASE_HOST: db
      DATABASE_USERNAME: postgres
      DATABASE_PASSWORD: password
      RAILS_ENV: development

volumes:
  postgres_data: # Define the named volume for data persistence
```

### Step 4: Configure `config/database.yml`

Now, we need to modify the Rails database configuration to read the environment variables we defined in `docker-compose.yml`. This makes your app portable.

Open `config/database.yml` and replace its contents with this:

```yaml
# config/database.yml

default: &default
  adapter: postgresql
  encoding: unicode
  host: <%= ENV.fetch("DATABASE_HOST") %>
  username: <%= ENV.fetch("DATABASE_USERNAME") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD") %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: todo_web_development

test:
  <<: *default
  database: todo_web_test
```

### Step 5: Build and Run Everything

You now have all the configuration in place. You can manage your entire application stack with a few `docker-compose` commands.

1.  **Build the `web` image**:
    This command reads your `Dockerfile` and builds the custom image for your Rails app.

    ```bash
    docker-compose build
    ```

2.  **Create the Database**:
    This command starts up the `db` and `web` services, runs `rails db:create` inside a new `web` container, and then stops them.

    ```bash
    docker-compose run --rm web rails db:create
    ```

3.  **Run the Scaffold and Migration**:
    Just like before, we'll run the Rails generators inside the container.

    ```bash
    docker-compose run --rm web rails generate scaffold Item title:string notes:text priority:string archived:boolean
    docker-compose run --rm web rails db:migrate
    ```

      * The `--rm` flag automatically cleans up the temporary container after the command finishes.

4.  **Start the Application**:
    This is the command you'll use to start your development server.

    ```bash
    docker-compose up
    ```

Your Rails app will now be running and accessible at [http://localhost:3000/items](https://www.google.com/search?q=http://localhost:3000/items). The best part is that thanks to the `volumes` mapping, any change you make to your local code will be instantly reflected inside the container.

### Your New Docker Workflow

  * **To Stop**: Press `Ctrl+C` in the terminal where `docker-compose up` is running. To ensure containers are fully stopped and removed, run `docker-compose down`.
  * **To Run any Rails command** (like `rails console` or another `generate` command):
    ```bash
    docker-compose run --rm web [YOUR COMMAND]
    # Example:
    docker-compose run --rm web rails console
    ```
