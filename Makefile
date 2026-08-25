.PHONY: lint test build

# Guarded on the Swift toolchain (same pattern as sdks/python): machines
# without Xcode/Swift no-op honestly instead of failing repo-wide make test.
ifeq (,$(shell command -v swift 2>/dev/null))
lint test build:
	@echo "sdks/swift-link: swift toolchain not installed — skipping $@"
else
build:
	swift build

test:
	swift test

# No SwiftLint dependency; `swift build` warnings serve as lint for now.
lint: build
endif
