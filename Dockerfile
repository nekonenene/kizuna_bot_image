ARG RUBY_VER="latest"
ARG ENV_FILE_DIR="."

FROM ruby:${RUBY_VER}

WORKDIR /home/repo/src

ADD src /home/repo/src
ADD ${ENV_FILE_DIR}/.env ../
RUN bundle install

CMD bundle exec ruby kizuna_bot.rb
