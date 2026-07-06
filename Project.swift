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
            scripts: [
                .pre(
                    script: "sh \"$SRCROOT/Scripts/validate_admob_release_config.sh\"",
                    name: "Validate Release AdMob Configuration",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .package(product: "GoogleMobileAds"),
                .target(name: "TimeNestWidgetExtension")
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
                    "CODE_SIGN_ENTITLEMENTS": "TimeNest/TimeNest.entitlements",
                    "CODE_SIGN_STYLE": "Automatic",
                    "CURRENT_PROJECT_VERSION": "3",
                    "DEVELOPMENT_TEAM": "JCABFH9F66",
                    "MARKETING_VERSION": "1.1",
                    "TARGETED_DEVICE_FAMILY": "1,2"
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        settings: [
                            "TIMENEST_ADMOB_APP_ID": "ca-app-pub-3940256099942544~1458002511",
                            "TIMENEST_ADMOB_BANNER_UNIT_ID": "ca-app-pub-3940256099942544/2435281174",
                            "TIMENEST_ADS_ENABLED": "YES"
                        ]
                    ),
                    .release(
                        name: "Release",
                        settings: [
                            "TIMENEST_ADMOB_APP_ID": "ca-app-pub-7907716708037277~6985657856",
                            "TIMENEST_ADMOB_BANNER_UNIT_ID": "ca-app-pub-7907716708037277/8542282103",
                            "TIMENEST_ADMOB_APP_ID[sdk=iphonesimulator*]": "ca-app-pub-3940256099942544~1458002511",
                            "TIMENEST_ADMOB_BANNER_UNIT_ID[sdk=iphonesimulator*]": "ca-app-pub-3940256099942544/2435281174",
                            "TIMENEST_ADS_ENABLED": "YES"
                        ]
                    )
                ]
            )
        ),
        .target(
            name: "TimeNestWidgetExtension",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.song.TimeNest.TimeNestWidgetExtension",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "TimeNest",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "ITSAppUsesNonExemptEncryption": false,
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ]
            ]),
            sources: [
                "TimeNestWidgetExtension/**",
                "TimeNest/Shared/Widgets/**"
            ],
            resources: [
                "TimeNest/Resources/{zh-Hans,zh-Hant,ja,en,ko}.lproj/Localizable.strings"
            ],
            settings: Settings.settings(
                base: [
                    "APPLICATION_EXTENSION_API_ONLY": "YES",
                    "CODE_SIGN_ENTITLEMENTS": "TimeNestWidgetExtension/TimeNestWidgetExtension.entitlements",
                    "CODE_SIGN_STYLE": "Automatic",
                    "CURRENT_PROJECT_VERSION": "3",
                    "DEVELOPMENT_TEAM": "JCABFH9F66",
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "MARKETING_VERSION": "1.1",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.song.TimeNest.TimeNestWidgetExtension",
                    "SKIP_INSTALL": "YES",
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
