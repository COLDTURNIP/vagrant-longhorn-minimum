#!/bin/bash

image_name=$1

docker save -o shared/import_image.tar "$image_name"
for node in $(vagrant status | grep k3s- | cut -d' ' -f1); do
  vagrant ssh "$node" - sudo k3s ctr images import /vagrant_shared/import_image.tar
done
