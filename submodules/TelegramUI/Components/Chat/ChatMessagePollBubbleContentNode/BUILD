load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessagePollBubbleContentNode",
    module_name = "ChatMessagePollBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/PtgForeignAgentNoticeRemoval",
        
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/TextFormat",
        "//submodules/UrlEscaping",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/AvatarNode",
        "//submodules/TelegramPresentationData",
        "//submodules/ChatMessageBackground",
        "//submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/Chat/PollBubbleTimerNode",
        "//submodules/TelegramUI/Components/Chat/MergedAvatarsNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
