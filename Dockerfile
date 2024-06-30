FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

COPY --chmod=755 apt.postgresql.org.sh ./

RUN apt-get update && apt-get install ca-certificates -y \
    && ./apt.postgresql.org.sh -y \
    && apt-get install postgresql-15 postgresql-client-15 -y
RUN apt-get install software-properties-common -y

# Copy the app folder into the image
COPY --chmod=755 . .

EXPOSE 3000

FROM python:3.11
COPY requirements.txt /opt/app/requirements.txt
WORKDIR /opt/app
RUN pip install --no-cache-dir -r requirements.txt
COPY . /opt/app

RUN pip install -r requirements.txt
