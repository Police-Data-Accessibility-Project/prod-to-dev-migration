FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

COPY apt.postgresql.org.sh ./
COPY requirements.txt ./
COPY setup.sh ./

RUN apt-get update && apt-get install ca-certificates -y
RUN chmod +x setup.sh apt.postgresql.org.sh && ./setup.sh
RUN apt-get install software-properties-common -y

FROM python:3.11
RUN pip install --no-cache-dir -r requirements.txt
# Copy the app folder into the image
COPY --chmod=755 . .

EXPOSE 3000
