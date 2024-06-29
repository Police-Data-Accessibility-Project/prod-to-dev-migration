FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

COPY apt.postgresql.org.sh ./
COPY requirements.txt ./
COPY setup.sh ./

RUN chmod +x setup.sh && ./setup.sh

# Copy the app folder into the image
COPY . .

EXPOSE 3000
