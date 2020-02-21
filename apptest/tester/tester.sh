#!/bin/bash
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -xeo pipefail
shopt -s nullglob

EXTERNAL_IP="$(kubectl get service/${APP_INSTANCE_NAME}-viewer \
--namespace ${NAMESPACE} \
--output jsonpath='{.status.loadBalancer.ingress[0].ip}')"

export EXTERNAL_IP

VIEWER_PASSWORD="$(kubectl get secrets --namespace ${NAMESPACE} \
    ${NAMESPACE}-password --output jsonpath='{.data.viewer-password}' | base64 -d -)"

export VIEWER_PASSWORD

for test in /tests/*; do
  testrunner -logtostderr "--test_spec=${test}"
done