FROM alpine:latest

ADD downwardapi-injector /downwardapi-injector
ENTRYPOINT ["./downwardapi-injector"]