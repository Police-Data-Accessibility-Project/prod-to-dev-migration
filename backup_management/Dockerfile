FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

# Install PostgreSQL and dependencies
RUN apt-get update && apt-get install ca-certificates -y
RUN apt install -y postgresql-common
RUN /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
RUN apt-get install postgresql-15 postgresql-client-15 -y

RUN apt-get install software-properties-common -y

# Install Python and pip
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip

# This section ensures that the Python package installation built inside the Dockerfile
# is accessible within the container.
COPY requirements.txt /opt/app/requirements.txt
WORKDIR /opt/app
RUN pip install --no-cache-dir -r requirements.txt --break-system-packages
COPY . /opt/app

# Copy the app folder into the image
COPY --chmod=755 . .

EXPOSE 3000

