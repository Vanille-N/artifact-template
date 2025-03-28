FROM debian:bookworm

# Install the system dependencies
RUN apt update -y
RUN apt install -y \
  git rsync tar unzip curl sudo build-essential \
  openssl libssl-dev pkg-config

# Create the user that will run the tests
RUN useradd -m user
RUN usermod -aG sudo user
RUN echo "user:password" | chpasswd

# Copy over all source code from the host to the container's `/home/user`
COPY README.md \
  /home/user/

# Finally as our last action as root we give
# `user` the ownership of all relevant files.
RUN chown -R user:user /home/user/
RUN chmod -R u+rwx /home/user/

# Switch to `user` and build from source.
USER user
ENV LANG=C.UTF-8

WORKDIR /home/user
RUN : > md5sums

