ARG RUBY_VER="latest"
FROM ruby:${RUBY_VER}

ARG ENV_FILE_DIR="."

WORKDIR /home/repo/src

ADD src /home/repo/src
ADD ${ENV_FILE_DIR}/.env ../
RUN bundle install

CMD bundle exec ruby kizuna_bot.rb
