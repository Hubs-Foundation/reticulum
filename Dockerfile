FROM elixir:1.5
RUN apt-get update -qq && apt-get install -y inotify-tools 
RUN curl -sL https://deb.nodesource.com/setup_10.x |  bash -
RUN apt-get install -y nodejs
RUN curl -so- -L https://yarnpkg.com/install.sh | bash
RUN mkdir /ret
WORKDIR	/ret
COPY mix.exs /ret/mix.exs
COPY mix.lock /ret/mix.lock
RUN mix local.hex --force
RUN mix local.rebar --force
COPY . /ret
