FROM ruby
MAINTAINER jason@thesparktree.com


RUN apt-get -q update && \
    apt-get install -qy --force-yes curl nano
RUN gem install rubygems-update --no-ri --no-rdoc
RUN update_rubygems
RUN gem install bundler --no-ri --no-rdoc

#Create folder structure & set as volumes
RUN mkdir -p /srv/rancher-events

#Copy over start script and docker-gen files
ADD ./daemon.rb /srv/rancher-events/daemon.rb
ADD ./events.rb /srv/rancher-events/events.rb
ADD ./Gemfile /srv/rancher-events/Gemfile

WORKDIR /srv/rancher-events
RUN bundle install


VOLUME [ "/srv/rancher-events"]

CMD ["ruby","events.rb"]