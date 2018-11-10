# Docker file to build the service broker image
FROM golang AS build
WORKDIR /go/src
COPY src github.com/awslabs/aws-servicebroker
RUN /usr/bin/env CGO_ENABLED=0 \
    go install -ldflags='-s -w' github.com/awslabs/aws-servicebroker/cmd/servicebroker

FROM opensuse/leap
COPY --from=build /go/bin/servicebroker /
ENTRYPOINT [ "/servicebroker" ]
