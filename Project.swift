import ProjectDescription

let project = Project(
    name: "TimeNest",
    packages: [
        .remote(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            requirement: .upToNextMajor(from: "13.0.0")
        )
    ],
    targets: [
        .target(
            name: "TimeNest",
            destinations: .iOS,
            product: .app,
            bundleId: "com.song.TimeNest",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .file(path: "TimeNest/Info.plist"),
            sources: ["TimeNest/**"],
            resources: [
                "TimeNest/Resources/**/*.strings",
                "TimeNest/PrivacyInfo.xcprivacy",
                "TimeNest/Resources/Assets.xcassets"
            ],
            dependencies: [
                .package(product: "GoogleMobileAds")
            ],
            settings: Settings.settings(
                base: [
                    "INFOPLIST_FILE": "TimeNest/Info.plist",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.song.TimeNest",
                    "PRODUCT_BUNDLE_PACKAGE_TYPE": "APPL",
                    "MACH_O_TYPE": "mh_execute",
                    "SKIP_INSTALL": "NO",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "GENERATE_INFOPLIST_FILE": "NO",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "S5NA4Y24ZD",
                    "TARGETED_DEVICE_FAMILY": "1,2"
                ]
            )
        ),
        .target(
            name: "TimeNestTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.song.TimeNestTests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Tests/TimeNestTests/**"],
            dependencies: [.target(name: "TimeNest")]
        )
    ]
)
