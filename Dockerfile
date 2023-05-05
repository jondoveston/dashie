# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.2.2
ARG BUNDLE_VERSION=2.4.12

###############################################################################
# Base stage
FROM ruby:${RUBY_VERSION}-slim as base

ARG APP_DIR=/src
ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} app && useradd -u ${UID} -g ${GID} app

ENV APP_DIR ${APP_DIR}
WORKDIR $APP_DIR

RUN chown ${UID}:${GID} ${APP_DIR}

# This is required to install the other dependencies
RUN apt-get update && apt-get install -y tini gnupg curl apt-transport-https nodejs \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*.log /var/cache/debconf/*-old

ENV BUNDLE_PATH vendor/bundle

###############################################################################
# Build stage
FROM base as build

ARG BUNDLE_VERSION
ENV BUNDLE_VERSION ${BUNDLE_VERSION}

# System deps for app
RUN apt-get update \
	&& apt-get install -y build-essential libxml2-dev libxslt1-dev shared-mime-info git \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*.log /var/cache/debconf/*-old

RUN gem install bundler -v ${BUNDLE_VERSION}

ENV BUNDLE_FORCE_RUBY_PLATFORM 1
ENV BUNDLE_BUILD__NOKOGIRI --use-system-libraries
ENV BUNDLE_DEPLOYMENT 1
ENV BUNDLE_CLEAN 1
ENV BUNDLE_DISABLE_SHARED_GEMS 1
ENV BUNDLE_FROZEN 1
ENV BUNDLE_WITHOUT development
ENV RACK_ENV production

COPY --chown=app:app Gemfile Gemfile.lock ./
RUN bundle install

###############################################################################
# Release stage
FROM base as release

ARG APP_VERSION
ENV APP_VERSION ${APP_VERSION}

COPY --chown=app:app . .
COPY --chown=app:app --from=build $APP_DIR/vendor/bundle vendor/bundle

ENV PORT 8000
EXPOSE ${PORT}

USER app
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bundle","exec","smashing","start","-p","8000","-a","0.0.0.0"]
