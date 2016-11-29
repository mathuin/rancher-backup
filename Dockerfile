FROM alpine
RUN apk --no-cache add --update \
    curl 
COPY ./backup.sh /
CMD /backup.sh
