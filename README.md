# sell_set_go_api

## About the sell set go API

DZINE HUB Project

This project helps the sellers to list their items and configure the item condition, price, quantity, and payment options on eBay. It will suggest the category for your item on eBay. It also has the feature to upload CSV files to import the items. Retrieve an array of item specifics that are appropriate for describing item in a specified category or we can specify it manually. Fetches all details in the eBay orders list and save a copy in the DB Show brief info in the grid and detail info when the user clicks the order.

## Prerequisites

This is an example of how to list things you need to use the software and how to install them

- Docker >= 20.10.9
- Elixir >= 1.10.3
- Erlang >= 11.1.8
- PostgreSQL >= 14.0

---

## Installation

This is an example of how you may give instructions on setting up your project locally. To get a local copy up and running follow these simple example steps.

### Install the git on Local Environment

Refer https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

### Cloning the repository

    $ git clone https://github.com/pmangala-Iteron/sell_set_go_api.git

This will clone the repository into your local directory, where you are executing the above command.

Get into cloned directory using

    $ cd sell_set_go_api

### Setup project by building docker images

    $ docker-compose build

This project uses docker to containerize the Backend, Frontend, Database, and S3 Manager. The above command is used to build those containers and install the necessary packages mentioned on the docker file.

### To start the project

    $ docker-compose up

This command is used to run the docker containers, which are written in the docker-compose.yml file.

### To stop the project

    $ docker-compose down

This command is used to stop and cleanup resources.

### To execute the sellsetgo-api container

    $ docker exec -it sellsetgo-api-v2 sh

This is used to attach the interactive terminal which can get the input or give the standard output and can give standard errors.

Note: In order to make this to work, we should add the below key and values to docker-compose.yml

    stdin_open: true
    tty: true

### To get all dependencies

    $ mix deps.get

Used to get(update or get) all out-of-date dependencies.

### Creates a Database and migrates the tables, Have to run when the project setup is done. (Not every time it's up)

    mix ecto.setup

It will create, migrate and seed the default data to the local storage.

### To run the elixir shell in the backend container

    iex -S mix phx.server

Starts the application by configuring all endpoints servers to run
