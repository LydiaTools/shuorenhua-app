#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
TEST_BINARY="$(mktemp -d)/shuorenhua-prompt-tests"

xcrun swiftc \
  -parse-as-library \
  "$ROOT_DIR/Sources/PromptBuilder.swift" \
  "$ROOT_DIR/Tests/PromptBuilderTests.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"

xcrun swiftc -parse-as-library \
  "$ROOT_DIR/Sources/PromptBuilder.swift" \
  "$ROOT_DIR/Sources/BridgeProtocol.swift" \
  "$ROOT_DIR/Tests/BridgeProtocolTests.swift" \
  -o "$TEST_BINARY-bridge"
"$TEST_BINARY-bridge"

xcrun swiftc -parse-as-library \
  "$ROOT_DIR/Sources/ReplyTargetHeuristics.swift" \
  "$ROOT_DIR/Tests/ReplyTargetHeuristicsTests.swift" \
  -o "$TEST_BINARY-target"
"$TEST_BINARY-target"

xcrun swiftc -parse-as-library \
  -framework Security \
  -framework LocalAuthentication \
  "$ROOT_DIR/Sources/PromptBuilder.swift" \
  "$ROOT_DIR/Sources/DeepSeekService.swift" \
  "$ROOT_DIR/Tests/DeepSeekServiceTests.swift" \
  -o "$TEST_BINARY-deepseek"
"$TEST_BINARY-deepseek"

xcrun swiftc -parse-as-library \
  "$ROOT_DIR/Sources/CommitmentGuard.swift" \
  "$ROOT_DIR/Tests/CommitmentGuardTests.swift" \
  -o "$TEST_BINARY-guard"
"$TEST_BINARY-guard"

xcrun swiftc -parse-as-library \
  "$ROOT_DIR/Sources/ReplyMemory.swift" \
  "$ROOT_DIR/Tests/ReplyMemoryTests.swift" \
  -o "$TEST_BINARY-memory"
"$TEST_BINARY-memory"

xcrun swiftc -parse-as-library \
  "$ROOT_DIR/Sources/PromptBuilder.swift" \
  "$ROOT_DIR/Sources/DeepSeekService.swift" \
  "$ROOT_DIR/Sources/PrototypeEngine.swift" \
  "$ROOT_DIR/Tests/PrototypeEngineTests.swift" \
  -framework Security \
  -framework LocalAuthentication \
  -o "$TEST_BINARY-prototype"
"$TEST_BINARY-prototype"
