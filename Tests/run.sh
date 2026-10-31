#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .cache
swiftc -swift-version 5 -module-cache-path .cache Sources/Domain.swift Tests/main.swift -o .cache/domain-tests
.cache/domain-tests
swiftc -swift-version 5 -module-cache-path .cache \
  Sources/Domain.swift Sources/AppModel.swift Sources/Actions.swift Sources/KeypadInput.swift \
  Sources/KeypadLighting.swift Sources/CustomLighting.swift Tests/AppModel/main.swift \
  -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement -o .cache/model-tests
.cache/model-tests
clang -std=c99 -Wall -Wextra -Werror -IFirmware/src \
  Tests/ProtocolBridge.c Firmware/src/lighting_protocol.c -o .cache/protocol-bridge
swiftc -swift-version 5 -module-cache-path .cache Sources/Domain.swift \
  Tests/ProtocolInterop/main.swift -o .cache/protocol-interop-tests
.cache/protocol-interop-tests "$PWD/.cache/protocol-bridge"
