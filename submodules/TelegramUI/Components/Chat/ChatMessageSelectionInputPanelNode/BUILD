load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageSelectionInputPanelNode",
    module_name = "ChatMessageSelectionInputPanelNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AppBundle",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/Chat/ChatInputPanelNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
