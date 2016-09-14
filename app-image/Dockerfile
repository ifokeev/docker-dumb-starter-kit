FROM ruby:alpine

ARG PACKAGES="build-base linux-headers gcc abuild binutils ca-certificates cmake procps pcre-dev curl-dev openssl-dev libexecinfo-dev git libxml2-dev libxslt-dev readline-dev yaml-dev imagemagick-dev postgresql-dev nodejs pkgconf file"
ARG BUILD_PACKAGES=""
ENV PATH="/opt/passenger/bin:$PATH"

RUN mkdir -p /opt/passenger
COPY passenger /opt/passenger

RUN echo '' > /etc/apk/repositories && \
		echo 'http://nl.alpinelinux.org/alpine/edge/main/' >> /etc/apk/repositories && \
		echo 'http://nl.alpinelinux.org/alpine/edge/testing/' >> /etc/apk/repositories 

# default packages
RUN apk add --update --no-cache $PACKAGES
# PACKAGES TO BUILD
RUN apk add --update --no-cache $BUILD_PACKAGES

########################################### gems requires native compilation
RUN gem install nokogiri 
RUN gem install pg

########################################## cleanup
RUN apk del $BUILD_PACKAGES \
      rm -rf /var/cache/apk/* /tmp/*

#app dir
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
EXPOSE 3000


######################################### example rack app
RUN gem install rack
#RUN apk add --update --no-cache ruby-rack
COPY config.ru /usr/src/app/

CMD ["passenger", "start", "--no-install-runtime", "--no-compile-runtime"]
