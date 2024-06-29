FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

COPY apt.postgresql.org.sh ./
COPY requirements.txt ./
COPY setup.sh ./

RUN chmod +x apt.postgresql.org.sh && ./apt.postgresql.org.sh -y
RUN apt-get update
RUN apt-get install postgresql-15 postgresql-client-15 -y
RUN apt-get install software-properties-common -y
RUN apt-get install curl -y
RUN curl https://pyenv.run | bash

RUN chmod +x setup.sh && ./setup.sh

# Copy the app folder into the image
COPY . .

EXPOSE 3000
