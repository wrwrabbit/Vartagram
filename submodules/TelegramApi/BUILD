load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramApi",
    module_name = "TelegramApi",
    copts = [
        "-warnings-as-errors",
    ],
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/GZip:GZip",
    ],
    visibility = [
        "//visibility:public",
    ],
)
