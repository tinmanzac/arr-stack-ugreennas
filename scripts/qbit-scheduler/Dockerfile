FROM alpine:3.19

RUN apk add --no-cache curl tzdata

WORKDIR /app

COPY pause-resume.sh /app/
COPY crontab /etc/crontabs/root

RUN chmod +x /app/pause-resume.sh

# Run crond in foreground
CMD ["crond", "-f", "-l", "2"]
